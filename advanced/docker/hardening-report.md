# Image hardening report

Date of scans: 17 October 2026

Tool versions: Trivy 0.76.0, Syft 1.54.1, Cosign devel (go1.25.0)

## Comparison

| | Alpine (Milestone 2) | Distroless |
| --- | --- | --- |
| Image size | 256 MB on disk / 64.5 MB content | 209 MB on disk / 53.5 MB content |
| Packages listed by Syft | 235 (215 npm, 19 apk, 1 binary) | 80 (69 npm, 10 deb, 1 binary) |
| CRITICAL findings (Trivy) | 0 | 1 |
| HIGH findings (Trivy) | 4 | 6 |
| Shell available | Yes, BusyBox `sh` | No |
| HEALTHCHECK possible | Yes, `wget --spider` is in BusyBox | No, there is no shell and no `wget` |

Full severity breakdown:

- Alpine: 13 findings total — 0 CRITICAL, 4 HIGH, 8 MEDIUM, 1 LOW.
  12 of the 13 are `node-pkg`, 1 is an Alpine OS package.
- Distroless: 70 findings total — 1 CRITICAL, 6 HIGH, 35 MEDIUM, 27 LOW, 1 UNKNOWN.
  All 70 are Debian OS packages. `node-pkg` findings: **0**.

## What the numbers show

Distroless is smaller and contains roughly a third of the packages, but Trivy reports
*more* CVEs against it, not fewer — 70 against 13. The reason is that the two counts are
measuring different things. Every one of Alpine's 12 `node-pkg` findings comes from npm's
own bundled dependencies in `/usr/local/lib/node_modules/npm`, which distroless does not
ship at all, so that entire category drops to zero; in exchange, the Debian 12 base brings
70 OS-package findings that Alpine's musl userland simply does not have equivalents for.
All 7 of the distroless CRITICAL and HIGH findings are the same package, `libssl3`, and 6
of the 7 already have a fixed version available — so this is a stale base image rather than
an inherently weaker one, and it would mostly clear on a rebuild once Google publishes a
refreshed tag.

## Trade-off

What you lose is every tool you would normally reach for when something goes wrong. There
is no shell, so `docker exec -it ... sh` fails outright with
`exec: "sh": executable file not found in $PATH`. No package manager, so you cannot install
one. No `curl`, no `wget`, no `ps`, no `ls`. That also kills the Dockerfile `HEALTHCHECK`
from Milestone 2, because it was a `wget` call — health has to be checked from outside the
container instead, by Compose or by a Kubernetes `httpGet` probe.

To debug a crashing container I would work from the outside in:

1. `docker logs <name>` first — the app's own stdout still works, and this is what actually
   found the bug in my first distroless build (`Cannot find module '/home/nonroot/node'`).
2. `docker inspect <name>` for the exit code, the resolved entrypoint and command, the
   environment and the mounts, since a wrong `CMD` is the most common cause.
3. Re-run the same image with a debug entrypoint if the base allows it, or temporarily
   rebuild the final stage `FROM gcr.io/distroless/nodejs24-debian12:debug`, which adds a
   BusyBox shell for exactly this purpose and is meant to be swapped back out afterwards.
4. Copy files out rather than going in — `docker cp <name>:/app/index.js -` works without
   any binary inside the container.
5. As a last resort, run the identical application layer on the Alpine image, where a shell
   exists, to decide whether the fault is in the app or in the runtime image.

The honest summary is that distroless trades debuggability for a smaller attack surface.
That is a good trade in production, where the thing should be replaced rather than poked
at, and a bad one on a laptop while you are still finding out why it will not boot.

## Signing

Image signed: `ghcr.io/mohammedawwad2/shipfast-app@sha256:3ef622711899a55f9f2cbe15e148942b24e2f60d51f50fd387cb5dd0f25a0e83`

Why a digest and not a tag: a tag is a mutable pointer — anyone with write access to the
package can move `:latest` to different bytes at any time. A digest is a SHA-256 hash of the
image manifest, which itself lists the hash of every layer and of the config, so it is
derived from the content rather than assigned to it. Changing a single byte anywhere in the
image produces a different digest. Signing a tag therefore means "I approve whatever this
name points at today", which stops being true the moment the tag moves; signing a digest
means "I approve exactly these bytes", which cannot be undermined. This is also why cosign
now warns on tag input and says the ability to sign by tag will be removed.

Verify result:

```
$ cosign verify --key cosign.pub ghcr.io/mohammedawwad2/shipfast-app@sha256:3ef622711899a55f9f2cbe15e148942b24e2f60d51f50fd387cb5dd0f25a0e83

Verification for ghcr.io/mohammedawwad2/shipfast-app@sha256:3ef622711899... --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key
```

The image carries two valid signatures from the same key, at Rekor log indexes
`3294975228` and `3294996721`. The first came from an attempt that pushed its signature and
then failed on a malformed second argument; the second came from the clean run. Both verify,
and `cosign clean` would remove the spare from the registry — though the transparency-log
entries are permanent by design.

`cosign.key` is listed in `.gitignore` and does not appear in `git status`. Only
`cosign.pub` is committed.

## Where I got stuck

`Dockerfile.distroless` built successfully but the container exited immediately with
`Error: Cannot find module '/home/nonroot/node'`. Two causes, both invisible in the build
output:

1. The runtime stage copied nothing from the build stage, so `/app` was empty.
2. The distroless Node images already set `ENTRYPOINT ["/nodejs/bin/node"]`, so a
   Milestone 2-style `CMD ["node", "index.js"]` is appended to it and runs
   `node node index.js` — Node then treats the literal word `node` as a module path.

The fix was `COPY --from=build --chown=nonroot:nonroot /app /app` plus
`CMD ["index.js"]`, with the script path alone. The `HEALTHCHECK` was removed in the same
change, since distroless has no shell to run it.
