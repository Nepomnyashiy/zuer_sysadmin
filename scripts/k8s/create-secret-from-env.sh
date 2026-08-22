#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <namespace> <secret-name> <env-file> [KEY ...]" >&2
  echo "At least one allowlisted KEY is required; whole-file import is disabled." >&2
  exit 2
fi

namespace="$1"
secret_name="$2"
env_file="$3"
shift 3

if [[ ! -f "$env_file" ]]; then
  echo "Env file not found: $env_file" >&2
  exit 1
fi

secret_env_file="$env_file"
temp_env_file=""

umask 077
temp_env_file="$(mktemp)"
trap 'rm -f "$temp_env_file"' EXIT
secret_env_file="$temp_env_file"

for key in "$@"; do
  if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Invalid environment key: $key" >&2
    exit 2
  fi

  if ! awk -v wanted="$key" '
    index($0, wanted "=") == 1 {
      value = substr($0, length(wanted) + 2)
      if (length(value) == 0) exit 1
      print
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$env_file" >>"$temp_env_file"; then
    echo "Required non-empty key not found in $env_file: $key" >&2
    exit 1
  fi
done

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic "$secret_name" \
  --namespace "$namespace" \
  --from-env-file "$secret_env_file" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "Secret $namespace/$secret_name created or updated from $env_file"
