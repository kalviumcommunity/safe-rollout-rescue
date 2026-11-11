#!/usr/bin/env bash
# Student-run infrastructure preparation. Never repairs planted defects.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
CLUSTER=cloud-m4-q2
NS=rollout-ca
MODE=rollout
fail() { echo "SETUP FAILED: $*" >&2; exit 1; }
for tool in docker kubectl curl python3; do
  command -v "$tool" >/dev/null || fail "Install $tool before starting the timer."
done
docker info >/dev/null 2>&1 || fail 'Start Docker-compatible engine, then retry.'
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(docker info --format '{{.Architecture}}')
case "$ARCH" in arm64|aarch64) ARCH=arm64;; amd64|x86_64) ARCH=amd64;; *) fail 'Unsupported Docker engine architecture.';; esac
if [ "$MODE" = delivery ] && [ "$ARCH" != amd64 ]; then
  fail 'Q4 hosted-runner artifacts are linux/amd64. Use an amd64 Docker engine/workstation; native arm64 is not supported for this lab.'
fi
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in arm64|aarch64) HOST_ARCH=arm64;; amd64|x86_64) HOST_ARCH=amd64;; *) fail 'Unsupported host architecture.';; esac
case "$OS" in linux|darwin) ;; *) fail 'Use Linux, macOS, or WSL2 with Docker integration.';; esac
mkdir -p .lab/bin
[ ! -e .lab/prepared ] || fail 'Already prepared. Do not rerun during tasks. For a fresh attempt use cleanup instructions in README.'
KIND="$ROOT/.lab/bin/kind"
if [ ! -x "$KIND" ]; then
  URL="https://kind.sigs.k8s.io/dl/v0.27.0/kind-$OS-$HOST_ARCH"
  curl -fL --retry 3 "$URL" -o "$KIND.download"
  curl -fL --retry 3 "$URL.sha256sum" -o "$KIND.sha256sum"
  python3 - "$KIND.download" "$KIND.sha256sum" <<'PY'
import hashlib, pathlib, sys
actual = hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest()
expected = pathlib.Path(sys.argv[2]).read_text().split()[0]
if actual != expected:
    raise SystemExit('kind checksum mismatch')
PY
  mv "$KIND.download" "$KIND"; chmod +x "$KIND"
fi
# Explicit kubeconfig and context on every call: never mutate ~/.kube/config.
if ! "$KIND" get clusters | grep -qx "$CLUSTER"; then
  "$KIND" create cluster --name "$CLUSTER" --image kindest/node:v1.32.2 --kubeconfig "$ROOT/.lab/kubeconfig" --wait 180s
fi
"$KIND" get kubeconfig --name "$CLUSTER" > .lab/kubeconfig
chmod 600 .lab/kubeconfig
k() { kubectl --kubeconfig "$ROOT/.lab/kubeconfig" --context "kind-$CLUSTER" "$@"; }
k wait --for=condition=Ready nodes --all --timeout=180s
k get nodes -o json > .lab/nodes.json
python3 - "$MODE" .lab/nodes.json <<'PY'
import json, sys
nodes = json.load(open(sys.argv[2]))['items']
def cpu(s): return float(s[:-1])/1000 if s.endswith('m') else float(s)
def memory(s):
    for suffix, factor in [('Ki',1024),('Mi',1024**2),('Gi',1024**3),('Ti',1024**4)]:
        if s.endswith(suffix): return float(s[:-len(suffix)])*factor
    return float(s)
for n in nodes:
    a = n['status']['allocatable']
    c, m = cpu(a['cpu']), memory(a['memory'])
    if c < 2 or m < 2*1024**3:
        raise SystemExit('Need >=2 allocatable CPU and >=2 GiB memory on lab node; increase Docker resources before timer.')
    if sys.argv[1] == 'triage' and c >= 16 and m >= 64*1024**3:
        raise SystemExit('Triage node too large: limit Docker to <16 CPUs or <64 GiB so scheduling fault remains observable.')
PY
k get namespace "$NS" >/dev/null 2>&1 || k create namespace "$NS"
load_image() {
  # Import host platform only; avoids incomplete multi-platform Docker indices.
  docker image save "$1" | docker exec --privileged -i "$CLUSTER-control-plane" ctr --namespace=k8s.io images import --platform "linux/$ARCH" --digests -
}
case "$MODE" in
  triage)
    docker build -t triage-api:1.0.0 .
    load_image triage-api:1.0.0
    k -n "$NS" apply -f k8s/
    # Intentionally no rollout wait: starter must remain unschedulable.
    ;;
  rollout)
    for version in 1.0.0 2.0.0; do
      docker build --build-arg "APP_VERSION=$version" -t "rollout-api:$version" .
      load_image "rollout-api:$version"
    done
    # Invalid Service is deliberately left unapplied.
    k -n "$NS" apply -f k8s/deployment.yaml
    k -n "$NS" rollout status deployment/rollout-api --timeout=180s
    ;;
  scaling)
    docker build -t scaling-api:1.0.0 .
    load_image scaling-api:1.0.0
    docker pull registry.k8s.io/metrics-server/metrics-server:v0.7.2
    load_image registry.k8s.io/metrics-server/metrics-server:v0.7.2
    curl -fL --retry 3 https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.2/components.yaml -o .lab/metrics-server.yaml
    k apply -f .lab/metrics-server.yaml
    # Disposable kind nodes have self-signed kubelet certificates. Lab only.
    k -n kube-system patch deployment metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    k -n kube-system rollout status deployment/metrics-server --timeout=180s
    READY=0
    for attempt in $(seq 1 60); do
      if k top nodes; then READY=1; break; fi
      sleep 5
    done
    [ "$READY" = 1 ] || fail 'Metrics unavailable. Resolve before timer; do not start tasks.'
    k -n "$NS" apply -f k8s/
    k -n "$NS" rollout status deployment/scaling-api --timeout=180s
    ;;
  delivery)
    # No application artifact exists yet. Task 3 imports final green run.
    ;;
esac
printf 'export KUBECONFIG=%q\nexport NS=%q\n' "$ROOT/.lab/kubeconfig" "$NS" > .lab/env.sh
touch .lab/prepared
printf '\nSETUP READY: %s / %s\nIn EACH task terminal: source .lab/env.sh\n' "$CLUSTER" "$NS"
echo 'Preparation complete. Start timer only after README checks. Do not rerun setup during tasks.'
