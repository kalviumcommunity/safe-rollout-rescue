#!/usr/bin/env bash
# Sends one HTTP GET from inside the cluster using a short-lived client pod.
# Usage: bash scripts/request.sh <namespace> <url>
# Example: bash scripts/request.sh rollout-ca http://rollout-api/health
set -euo pipefail
NS="${1:?namespace required}"
URL="${2:?url required}"
kubectl -n "$NS" run "client-$(date +%s)" --rm -i --quiet --restart=Never \
  --image=rollout-api:1.0.0 --image-pull-policy=Never --command -- \
  python -c "import sys,urllib.request as u
try:
    r=u.urlopen(sys.argv[1],timeout=5); print('HTTP',r.status); print(r.read().decode())
except Exception as e:
    print('REQUEST FAILED:',e); sys.exit(1)" "$URL"
