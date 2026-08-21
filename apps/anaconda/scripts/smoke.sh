#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-anaconda}"
node_port_url="${NODE_PORT_URL:-http://127.0.0.1:30080}"

kubectl -n "$namespace" rollout status statefulset/anaconda-postgres --timeout=180s
kubectl -n "$namespace" rollout status deployment/anaconda-api --timeout=180s
kubectl -n "$namespace" rollout status deployment/anaconda-web --timeout=180s

kubectl -n "$namespace" wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/data-anaconda-postgres-0 \
  --timeout=120s

curl --noproxy '*' -fsS \
  -H 'Host: api.anaconda.godny.tech' \
  "$node_port_url/live" >/dev/null
curl --noproxy '*' -fsS \
  -H 'Host: api.anaconda.godny.tech' \
  "$node_port_url/ready" >/dev/null
curl --noproxy '*' -fsS \
  -H 'Host: anaconda.godny.tech' \
  "$node_port_url/healthz" >/dev/null

printf '%s\n' 'Anaconda Kubernetes smoke test passed'
