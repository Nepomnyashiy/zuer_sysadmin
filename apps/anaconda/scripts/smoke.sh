#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-anaconda}"
node_port_url="${NODE_PORT_URL:-http://127.0.0.1:30080}"

kubectl -n "$namespace" rollout status deployment/anaconda-site --timeout=180s

curl --noproxy '*' -fsS \
  --retry 12 \
  --retry-delay 2 \
  --retry-all-errors \
  -H 'Host: anaconda.godny.tech' \
  "$node_port_url/healthz" >/dev/null

curl --noproxy '*' -fsS \
  --retry 12 \
  --retry-delay 2 \
  --retry-all-errors \
  -H 'Host: anaconda.godny.tech' \
  "$node_port_url/" >/dev/null

printf '%s\n' 'Anaconda Site Kubernetes smoke test passed'
