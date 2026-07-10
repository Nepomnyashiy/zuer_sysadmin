#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <namespace> <statefulset-or-pod-prefix> <database> <user>" >&2
  exit 2
fi

namespace="$1"
app="$2"
database="$3"
user="$4"
backup_root="${BACKUP_ROOT:-/mnt/ufiles/backups/k8s-postgres}"
timestamp="$(date +%Y%m%d-%H%M%S)"
target_dir="$backup_root/$namespace/$app"
target_file="$target_dir/${database}-${timestamp}.dump"

mkdir -p "$target_dir"

pod="$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app" -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$pod" ]]; then
  echo "No pod found for app.kubernetes.io/name=$app in namespace $namespace" >&2
  exit 1
fi

echo "Creating PostgreSQL dump from $namespace/$pod to $target_file"
kubectl exec -n "$namespace" "$pod" -- pg_dump -U "$user" -d "$database" -Fc >"$target_file"

chmod 600 "$target_file"
echo "Backup written: $target_file"

