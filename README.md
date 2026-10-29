# Safe Rollout Rescue

A notes API release needs a safe update strategy, recovery from a bad release, and NodePort access. Exactly three fault groups: unsafe Deployment strategy; version 2.0.0 crashes because its required configuration is unavailable; Service type/NodePort mismatch. Complete tasks in assessment order. Do not modify application code, images, or readiness checks.

## Intended design

- Deployment/container: `rollout-api` / `api`; one replica.
- Healthy image: `rollout-api:1.0.0`, already loaded on the node.
- Candidate image: `rollout-api:2.0.0`, also loaded. It deliberately exits when `NOTES_STORE_URL` is absent. This environment has no notes store: recover by rollback, not by inventing configuration.
- Container listens on 5000. `GET /health` returns HTTP 200 with status `ok` and version.
- Updates must keep one healthy replica: RollingUpdate, zero unavailable, at most one extra replica. Keep revision history and readiness checks.
- Final Service: `rollout-api`, NodePort **30080**, port 80 → targetPort 5000. Instructor reserves 30080 before timer.

## Prepared environment (before timer)

Instructor builds and loads both images into a free local cluster:

```bash
docker build --build-arg APP_VERSION=1.0.0 -t rollout-api:1.0.0 .
docker build --build-arg APP_VERSION=2.0.0 -t rollout-api:2.0.0 .
# kind: kind load docker-image rollout-api:1.0.0 rollout-api:2.0.0 --name <cluster>
# minikube: minikube image load rollout-api:1.0.0 rollout-api:2.0.0
kubectl create namespace rollout-ca
kubectl -n rollout-ca apply -f k8s/deployment.yaml
kubectl -n rollout-ca rollout status deploy/rollout-api
```

Do not apply the broken Service during setup. No registry login, billing, cloud account, or secret needed. Use only assigned namespace; replace `rollout-ca` below if instructed.

## Task command reference

```bash
kubectl -n rollout-ca get deploy rollout-api -o yaml
kubectl -n rollout-ca apply -f k8s/deployment.yaml
kubectl -n rollout-ca rollout history deploy/rollout-api
# Task 2: introduce the supplied bad release only after Task 1 is complete:
kubectl -n rollout-ca set image deploy/rollout-api api=rollout-api:2.0.0
kubectl -n rollout-ca rollout status deploy/rollout-api --timeout=75s
kubectl -n rollout-ca get pods
kubectl -n rollout-ca logs <failing-pod-name>
kubectl -n rollout-ca rollout undo deploy/rollout-api
kubectl -n rollout-ca rollout status deploy/rollout-api
# Keep deployment.yaml at the recovered healthy image, then apply it to verify no regression.
kubectl -n rollout-ca apply -f k8s/deployment.yaml
kubectl -n rollout-ca apply -f k8s/service.yaml
kubectl -n rollout-ca get svc,endpointslices
bash scripts/request.sh rollout-ca http://rollout-api/health
# Prove NodePort routing too (use a node's InternalIP):
kubectl get nodes -o wide
bash scripts/request.sh rollout-ca http://<node-internal-ip>:30080/health
```

Task 2's failed rollout and rollback are runtime operations; do not commit the bad candidate as final desired state. Keep `k8s/deployment.yaml` on version 1.0.0. Allowed file edits: `k8s/deployment.yaml`, `k8s/service.yaml`, and your `repair-notes.md`. Commit repaired manifests and notes to your fork.
