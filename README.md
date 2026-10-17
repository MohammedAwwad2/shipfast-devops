# ShipFast DevOps

ShipFast is a small Express service used as the running example through the
DevOps lifecycle capstone: a local bootstrap script, a container image published
to GitHub Container Registry, and an Ansible deployment exercise.

## Repository layout

```text
app/                             Express app, static page, tests, Dockerfile
app/Dockerfile                   Production image, non-root, with a health check
app/.dockerignore                Keeps the build context to a few kilobytes
advanced/ansible/                Inventory, playbook, and systemd service template
advanced/docker/                 Distroless build, SBOM, cosign public key, hardening report
docker-compose.yml               Single-service Compose definition
bootstrap.sh                     Checks local tools, installs deps, starts the app
docs/week-3/                     Assignment reports with verified command output
```

## Reports

Written up with the captured output of every command, under `docs/week-3/`:

| Report | Covers |
| --- | --- |
| `shipfast-containerisation.pdf` | Milestone 2 — Dockerfile, Compose, GHCR |
| `week3-progress-check.pdf` | Checkpoints 1–5 and the Week 2 review |
| `shipfast-a3-harden-and-sign.pdf` | Lab A3 — distroless, SBOM, Cosign |

## Local development

Requirements: Node.js 22 or newer and npm. Docker is optional for the local
bootstrap.

```bash
bash bootstrap.sh
```

The script verifies Node, npm, Git and Docker, installs the app dependencies
with `npm ci`, and then starts the app in the foreground. Stop it with Ctrl+C.

To work on the app directly:

```bash
cd app
npm test
npm start
```

The service listens on port 3000 by default. Set `PORT` to override it, for
example `PORT=8080 npm start`. Available endpoints are `/health`, `/api/info`,
and `/metrics`.

## Docker

The Dockerfile lives in `app/`, which is also the build context, so
`.dockerignore` sits beside it rather than at the repository root. The image
runs as the unprivileged `appuser` and carries a `HEALTHCHECK` that calls
`/health` with `wget`, which is available in the Alpine base image.

```bash
cd app
docker build --progress=plain \
  --build-arg REPO_URL=https://github.com/MohammedAwwad2/shipfast-devops \
  -t shipfast-app:1.0.0 .
docker run -d -p 3000:3000 --name shipfast shipfast-app:1.0.0
```

Pass `REPO_URL` on every build. It feeds the `org.opencontainers.image.source`
label, which is what links the published package to this repository on GHCR. A
build without it bakes in an empty label and the link silently does not appear.

Verify the container:

```bash
docker ps                                # STATUS should read (healthy)
curl -s localhost:3000/health
docker exec shipfast whoami              # appuser, not root
docker stop shipfast && docker rm shipfast
```

## Docker Compose

`docker-compose.yml` is at the repository root and builds from `app/`. Port 3000
must be free first, so stop any container or `bootstrap.sh` process still
holding it.

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f shipfast
docker compose down
```

## Published image

The image is published to GitHub Container Registry. Registry paths must be
entirely lowercase, so the username is `mohammedawwad2` even though the GitHub
account is spelled `MohammedAwwad2`.

```bash
docker pull ghcr.io/mohammedawwad2/shipfast-app:1.0.0
```

Tags `1.0.0` and `latest` point at the same digest.

The package is public, so the pull above needs no credentials. This matters for
Week 6, where Kubernetes pulls the image anonymously.

## Ansible deployment

The playbook targets the `shipfast` group in `advanced/ansible/inventory.ini`.
From that directory:

```bash
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass
```

The playbook installs the app as a systemd service and checks its health
endpoint. The target must run systemd and allow sudo privilege escalation.

### Notes for WSL

A checkout under `/mnt/c` is world-writable as far as Linux is concerned, so
Ansible refuses to read the local `ansible.cfg` and prints a warning. Pass
`-i inventory.ini` explicitly, as shown above, so the inventory is found anyway.

`systemd` must be enabled in the distro. Add this to `/etc/wsl.conf` and restart
WSL with `wsl --shutdown` from PowerShell:

```ini
[boot]
systemd=true
```

### Notes for Ubuntu 25.10 and newer

These releases ship **sudo-rs** as the default `sudo`. It does not read a
password from standard input, which is how Ansible's `become` supplies one, so
every task fails with `Timed out waiting for become success or become password
prompt` regardless of whether the password is correct. The classic sudo is still
installed; point the alternative back at it once:

```bash
sudo update-alternatives --set sudo /usr/bin/sudo.ws
```
