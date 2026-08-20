#!/usr/bin/env bash
set -euo pipefail

mode="${1:---plan}"
retention_hours="${DOCKER_PRUNE_RETENTION_HOURS:-168}"

if [[ "$mode" != "--plan" && "$mode" != "--apply" ]]; then
  printf 'Usage: %s [--plan|--apply]\n' "$0" >&2
  exit 2
fi
if [[ ! "$retention_hours" =~ ^[1-9][0-9]*$ ]]; then
  printf 'DOCKER_PRUNE_RETENTION_HOURS must be a positive integer.\n' >&2
  exit 2
fi

cutoff_epoch="$(( $(date +%s) - retention_hours * 3600 ))"
candidate_count=0
candidate_bytes=0

printf 'Dangling image candidates older than %s hours:\n' "$retention_hours"
while IFS= read -r image_id; do
  [[ -n "$image_id" ]] || continue
  read -r created size_bytes < <(docker image inspect --format '{{.Created}} {{.Size}}' "$image_id")
  created_epoch="$(date -d "$created" +%s)"
  if (( created_epoch <= cutoff_epoch )); then
    printf '%s\t%s\t%s bytes\n' "$image_id" "$created" "$size_bytes"
    candidate_count="$((candidate_count + 1))"
    candidate_bytes="$((candidate_bytes + size_bytes))"
  fi
done < <(docker image ls -q --filter dangling=true | sort -u)

printf 'candidate_count=%s logical_bytes=%s\n' "$candidate_count" "$candidate_bytes"
printf '\nDocker accounting before prune:\n'
docker system df

if [[ "$mode" == "--plan" ]]; then
  printf '\nPlan only: containers, volumes and tagged images will not be removed.\n'
  exit 0
fi

docker image prune --force --filter "until=${retention_hours}h"
docker builder prune --force --filter "until=${retention_hours}h"
printf '\nDocker accounting after prune:\n'
docker system df
