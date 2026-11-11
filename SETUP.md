# Local lab workstation and checks

Read before running `bash scripts/prepare-lab.sh` from repository root.

## Prerequisites

- Linux, macOS, or WSL2 with Docker integration; Bash, Python 3, curl, kubectl, Git and editor installed. Windows users run commands inside WSL2, not PowerShell.
- Docker-compatible engine running and accessible without sudo (`docker info`). Allow at least 2 allocatable CPUs and 2 GiB node memory; 4 CPUs and 6 GiB Docker memory recommended for system pods, four HPA pods and load client. Close competing workloads. Free disk recommended: 10 GiB.
- Internet access to GitHub, kind.sigs.k8s.io, Docker Hub and registry.k8s.io for setup downloads. Setup is not air-gapped. No registry login, paid cluster or cloud account needed. Q4 also needs GitHub Actions/artifact download access and an amd64 Docker engine; other labs support amd64 and arm64.
- `kubectl version --client` should be compatible with Kubernetes 1.32 (within one minor version). Resolve tool/version/network failures before starting timer.

Setup downloads checksum-verified kind v0.27.0 to `.lab/bin`, creates a single-node Kubernetes v1.32.2 cluster unique to this question, builds/loads required images, and initializes only the stated starter resources. It uses explicit context and `.lab/kubeconfig`; it does not switch or write your default kubeconfig. Use one checkout per question/cluster on a Docker engine. Cluster names are fixed per question (`cloud-m4-q1` through `cloud-m4-q4`); do not reuse another attempt's cluster.

## Ready checks

After setup prints `SETUP READY`, in **every** task terminal:

```bash
source .lab/env.sh
kubectl config current-context
kubectl get nodes
kubectl -n "$NS" get pods
```

Context must match `kind-cloud-m4-qN` for your question. Node must be Ready. Q1 starter pod must be Pending for resources; Q2 healthy 1.0.0 must be ready with Service absent; Q3 API must be ready and `kubectl top nodes` numeric (HPA target error is expected); Q4 namespace must be empty. Only then start timer. Helpers use current kubeconfig, so never omit `source .lab/env.sh`. Work only in this lab namespace. Do not apply resources to another cluster or namespace.

Preparation is ungraded. No helper changes are allowed as task solutions. Setup preserves all planted manifest/workflow defects; do not rerun after starting repairs. Q4 artifact loading is a later student-run transport step and never repairs/applies manifests. Capture genuine diagnostics and checks in labelled screenshots. Pause timer for unrelated environment failures; resolve before resuming.

## Failed setup and fresh attempts

An interrupted setup before `.lab/prepared` may be retried before timer; it reuses the question's cluster. If resources were already repaired or state is uncertain, start fresh instead. Do not delete shared clusters or workloads. The following deletes **all work in this question's disposable cluster**, so run only after finishing an attempt or explicitly abandoning it:

```bash
# Replace qN with this question's q1, q2, q3 or q4 (not another question):
.lab/bin/kind delete cluster --name cloud-m4-qN
rm -rf .lab
```

For a new attempt, restore a pristine starter checkout first, then run setup. Cleanup never requires editing your default kubeconfig. `.lab/` includes private kubeconfig and generated files; it is excluded from Git and Docker build context. Never commit or upload it.
