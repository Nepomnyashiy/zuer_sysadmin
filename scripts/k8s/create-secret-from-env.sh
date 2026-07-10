#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <namespace> <secret-name> <env-file>" >&2
  exit 2
fi

namespace="$1"
secret_name="$2"
env_file="$3"

if [[ ! -f "$env_file" ]]; then
  echo "Env file not found: $env_file" >&2
  exit 1
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-env-file "$env_file" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "Secret $namespace/$secret_name created or updated from $env_file"

