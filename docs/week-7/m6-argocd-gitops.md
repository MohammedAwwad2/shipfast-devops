# M6 — GitOps with Argo CD

Repo: https://github.com/MohammedAwwad2/shipfast-devops (public)
Cluster: minikube
App: `shipfast-app` in namespace `shipfast`

---

## Part 4 — Drift experiments

Predictions written before running the commands.

| # | Experiment | Prediction (before) | What happened | Seconds | Why |
|---|---|---|---|---|---|
| A | `kubectl scale deployment shipfast-app --replicas=1 -n shipfast` | Drops to 1 pod, then Argo CD puts it back to 2 on its own. Briefly OutOfSync, then Synced + Healthy. | Correct. `spec.replicas` went to 1, and was back to 2 almost immediately. UI showed Synced/Progressing, then Synced/Healthy. | **3** | Git says 2 replicas. Self-heal watches the cluster and pushes it back to match Git, so my manual change is undone. It never even reported OutOfSync in my samples because it corrected faster than I could poll. |
| B | `kubectl delete pod <name> -n shipfast` | A new pod starts immediately. Argo CD stays Synced + Healthy the whole time. | Mostly correct. Sync stayed **Synced** the whole time, but health dipped to **Progressing** for ~8s while the replacement pod became ready. | **8** | This is not drift. Git never named the pod — the Deployment did. The ReplicaSet replaces it, so nothing differs from Git and sync never moves. Only health reacts, because for a few seconds only 1 of 2 pods was ready. |
| C | `kubectl set image deployment/shipfast-app shipfast-app=ghcr.io/invalid/broken-image:nope -n shipfast` | New pod goes ImagePullBackOff. Argo CD sets it back to the Git image and the bad pod disappears. Momentarily OutOfSync and Degraded. | Partly wrong. I did catch **OutOfSync/Progressing** at 0s and the image was reverted. But self-heal was faster than the image pull, so the bad pod **never reached ImagePullBackOff** and health never went Degraded. Re-running it with self-heal off did show `ErrImagePull`. | **3** | Self-heal reverts the image. Sync = does the cluster match Git. Health = is the workload actually working. Here the manual edit broke sync, but self-heal killed the bad pod before it could break health. The two statuses answer different questions, and with self-heal on you may only ever see the sync one move. |
| D | Turn off self-heal, repeat A, turn it back on | Stays at 1 pod. Argo CD reports OutOfSync but Healthy, and does not fix it. When self-heal goes back on, it returns to 2. | Correct for the replica drift: held at **1 pod, OutOfSync / Healthy, for 69 seconds** with no correction. **But** when I then changed the image, an automated sync fired anyway and reverted *both* the image and the replica count. | **69+ (never self-healed)** | Without self-heal Argo CD notices drift but does not keep correcting it, and 1 pod is still a working app so health stays green. The surprise: `automated` sync is still enabled, so a later change can still trigger a sync that quietly fixes the drift too. Turning off self-heal is **not** a freeze. |

### What surprised me in D

Turning off `selfHeal` stopped Argo CD from *continuously* correcting drift — my 1 replica held for 69 seconds. But `syncPolicy.automated` was still on, and as soon as I made a second change (the bad image) an automated sync fired and reverted **everything**, including the replica count I thought was safe.

The sync was recorded as `initiatedBy: {automated: true}`, so nothing of mine triggered it.

Lesson: `selfHeal: false` is not a freeze. To really hold the cluster still you remove the whole `automated` block, or use `ignoreDifferences` for the one field you need to pin. This changes my answer to the 2am question below.

### Written answer — the 2am question

I would hold it at 1 replica **in Git**, not in the cluster. The honest option is to edit `k8s/base/deployment.yaml` to `replicas: 1`, commit and push — then Argo CD keeps it at 1 for me and the next person can see why. If I need it faster than a commit, I remove the whole `automated` block from the Application (or add `ignoreDifferences` for the replica count) and then scale by hand, and I write down that auto-sync is off. Experiment D taught me that turning off `selfHeal` alone is **not** enough — automated sync can still fire later and undo my change.

What I must not do is `kubectl scale` and walk away. Self-heal will silently put it back to 2 within a couple of minutes and I will think my change held when it did not. I also must not leave auto-sync disabled without telling anyone — the cluster then drifts from Git with nobody watching.

### Written answer — the Week 7 interview question

Nothing lasting happens. The cluster drops to 1 replica, Argo CD detects that the live state no longer matches `k8s/base/deployment.yaml`, and self-heal scales it straight back to 2 — usually within a few seconds of the next reconcile. So the developer's debugging change disappears underneath them, which is confusing if they do not know Argo CD is there. In GitOps, Git is the only source of truth: to actually hold it at 1 replica you commit that change to Git, or you turn off auto-sync first and say so. The manual `kubectl` route is not a shortcut, it just fails quietly.

---

## Part 3 — Deploy timings

| Attempt | What I did | Seconds until 3rd pod | Why |
|---|---|---|---|
| 1 | Pushed, waited, clicked nothing | **254** | Argo CD polls Git on a timer (180s default), so I waited for the next poll before it even looked. |
| 2 | Pushed, then clicked **Refresh** in the UI | **5** | Refresh makes Argo CD check Git at once, so only the rollout time is left. |

Two clocks: the **polling interval** (how soon Argo CD looks at Git) and the **sync/rollout time** (how fast Kubernetes then starts the pod). Only the first one changes between the two attempts.

---

## Part 5 — CI commits the image tag

### Written answer — rollback

I roll back with Git: `git revert` the pipeline's tag commit (or commit the previous tag) and push. Argo CD sees the older tag in `k8s/base/deployment.yaml` and rolls the Deployment back for me.

`kubectl rollout undo` would not work — or rather it would work for about a minute. It changes the cluster only, so the live image no longer matches Git, and self-heal puts the bad tag straight back. The rollback has to happen in the place Argo CD reads from.

### Why `application.yaml` lives in `k8s/argocd/`, not `k8s/base/`

Because `k8s/base/` is exactly what the Application tells Argo CD to deploy. If the Application sat in that folder, Argo CD would be managing itself: it would deploy its own definition, and anything it pruned or self-healed could affect the object doing the syncing. Keeping it in `k8s/argocd/` separates *what gets deployed* from *the thing that deploys it*.

---

## Evidence checklist

- [x] Argo CD pods Running in `argocd`
- [ ] UI shows `shipfast-app` Synced + Healthy with resource tree
- [x] Part 3 two timings recorded (254s / 5s)
- [x] Part 4 table filled in
- [ ] CI run link + Argo CD history showing the pipeline's commit
