#!/usr/bin/env bash
set -euo pipefail

namespace="$(printenv NAMESPACE 2>/dev/null || printf prombiz)"
node_port_url="$(printenv NODE_PORT_URL 2>/dev/null || printf http://127.0.0.1:30080)"

kubectl -n "$namespace" rollout status deployment/prombiz-site --timeout=180s

for path in /healthz /; do
  curl --noproxy '*' -fsS --retry 12 --retry-delay 2 --retry-all-errors \
    -H 'Host: prombiz.tech' "$node_port_url$path" >/dev/null
done

html="$(curl --noproxy '*' -fsS -H 'Host: prombiz.tech' "$node_port_url/")"
grep -q 'PROMBIZ.TECH' <<<"$html"
printf '%s\n' 'PromBiz.Tech Kubernetes smoke test passed'
