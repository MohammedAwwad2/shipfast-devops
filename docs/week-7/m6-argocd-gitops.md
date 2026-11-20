# M6 — GitOps with Argo CD

Repo: https://github.com/MohammedAwwad2/shipfast-devops (public)
Cluster: minikube
App: `shipfast-app` in namespace `shipfast`

---

## Part 4 — Drift experiments

Predictions written before running the commands.

| # | Experiment | Prediction (before) | What happened | Seconds | Why |
|---|---|---|---|---|---|
| A | `kubectl scale deployment shipfast-app --replicas=1 -n shipfast` | Drops to 1 pod, then Argo CD puts it back to 2 on its own. Briefly OutOfSync, then Synced + Healthy. | | | Git says 2 replicas. Self-heal makes the cluster match Git, so my manual change is undone. |
| B | `kubectl delete pod <name> -n shipfast` | A new pod starts immediately. Argo CD stays Synced + Healthy the whole time. | | | This is not drift. Git never named the pod — the Deployment did. The ReplicaSet replaces it, so nothing differs from Git. |
| C | `kubectl set image deployment/shipfast-app shipfast-app=ghcr.io/invalid/broken-image:nope -n shipfast` | New pod goes ImagePullBackOff. Argo CD sets it back to the Git image and the bad pod disappears. Momentarily OutOfSync and Degraded. | | | Self-heal reverts the image. Sync = does the cluster match Git. Health = is the workload actually working. The bad image breaks health, the manual edit breaks sync. |
| D | Turn off self-heal, repeat A, turn it back on | Stays at 1 pod. Argo CD reports OutOfSync but Healthy, and does not fix it. When self-heal goes back on, it returns to 2. | | | Without self-heal Argo CD only notices drift, it does not correct it. 1 pod is still a working app, so health stays green. |

### Written answer — the 2am question

I would hold it at 1 replica **in Git**, not in the cluster. The honest option is to edit `k8s/base/deployment.yaml` to `replicas: 1`, commit and push — then Argo CD keeps it at 1 for me and the next person can see why. If I need it faster than a commit, I disable auto-sync on the Application (or add `ignoreDifferences` for the replica count) and then scale by hand, and I write down that auto-sync is off.

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

- [ ] Argo CD pods Running in `argocd`
- [ ] UI shows `shipfast-app` Synced + Healthy with resource tree
- [ ] Part 3 two timings recorded
- [ ] Part 4 table filled in
- [ ] CI run link + Argo CD history showing the pipeline's commit
