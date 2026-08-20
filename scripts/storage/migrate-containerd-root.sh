#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
action="${1:---preflight}"
health_timeout_seconds="${CONTAINER_HEALTH_TIMEOUT_SECONDS:-600}"
if [[ ! "$health_timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  printf 'ERROR: CONTAINER_HEALTH_TIMEOUT_SECONDS must be a positive integer.\n' >&2
  exit 2
fi
source_root="/var/lib/containerd"
target_parent="/mnt/ufiles/container-runtime"
target_root="$target_parent/containerd"
target_marker="$target_parent/.osnova-containerd-target"
expected_uuid="548a00f5-dfd3-47d0-9879-b2a175b5bdb1"
storage_device="/dev/sdf"
min_free_bytes="$((100 * 1024 * 1024 * 1024))"
state_base="/var/lib/osnova-containerd-migration"
backup_ctl="/usr/local/sbin/osnova-backupctl"

usage() {
  printf 'Usage: sudo %s --preflight|--migrate|--verify|--rollback|--finalize\n' "$0" >&2
}

require_root() {
  if (( EUID != 0 )); then
    printf 'ERROR: root privileges are required.\n' >&2
    exit 1
  fi
}

check_mount() {
  local uuid options free_bytes
  mountpoint -q /mnt/ufiles || { printf 'ERROR: /mnt/ufiles is not mounted.\n' >&2; exit 1; }
  uuid="$(findmnt -rn -M /mnt/ufiles -o UUID)"
  options="$(findmnt -rn -M /mnt/ufiles -o OPTIONS)"
  [[ "$uuid" == "$expected_uuid" ]] || { printf 'ERROR: unexpected ufiles UUID: %s\n' "$uuid" >&2; exit 1; }
  [[ ",$options," == *,rw,* && ",$options," != *,ro,* ]] || { printf 'ERROR: /mnt/ufiles is not read-write.\n' >&2; exit 1; }
  free_bytes="$(df -B1 --output=avail /mnt/ufiles | awk 'NR == 2 {print $1}')"
  (( free_bytes >= min_free_bytes )) || { printf 'ERROR: ufiles has less than 100 GiB free.\n' >&2; exit 1; }
}

check_smart() {
  command -v smartctl >/dev/null || { printf 'ERROR: smartctl is required. Install smartmontools first.\n' >&2; exit 1; }
  local smart_output
  smart_output="$(smartctl -H "$storage_device" 2>&1)" || true
  printf '%s\n' "$smart_output"
  rg -q 'PASSED|OK' <<<"$smart_output" || { printf 'ERROR: SMART health is not confirmed for %s.\n' "$storage_device" >&2; exit 1; }
}

preflight() {
  check_mount
  check_smart
  systemctl is-active --quiet docker containerd k3s
  docker info --format '{{json .DriverStatus}}' | rg -q 'io.containerd.snapshotter.v1'
  [[ "$(docker info --format '{{.DockerRootDir}}')" == "/var/lib/docker" ]]
  [[ -d "$source_root" ]]
  printf 'Preflight passed.\n'
  df -hT / /mnt/ufiles
  docker system df
}

restore_running_set() {
  local state_dir="$1"
  if [[ -s "$state_dir/running-container-ids" ]]; then
    mapfile -t running_ids <"$state_dir/running-container-ids"
    docker start "${running_ids[@]}" >/dev/null
  fi
}

restore_original_runtime_config() {
  local state_dir="$1"
  if [[ -f "$state_dir/had-containerd-config" ]]; then
    install -m 0644 "$state_dir/containerd-config.toml" /etc/containerd/config.toml
  else
    rm -f -- /etc/containerd/config.toml
  fi
  if [[ -f "$state_dir/had-containerd-override" ]]; then
    install -m 0644 "$state_dir/containerd-storage.conf" \
      /etc/systemd/system/containerd.service.d/20-osnova-storage.conf
  else
    rm -f -- /etc/systemd/system/containerd.service.d/20-osnova-storage.conf
  fi
  if [[ -f "$state_dir/had-docker-storage-override" ]]; then
    install -m 0644 "$state_dir/docker-storage-mounts.conf" \
      /etc/systemd/system/docker.service.d/10-storage-mounts.conf
  else
    rm -f -- /etc/systemd/system/docker.service.d/10-storage-mounts.conf
  fi
  if [[ -f "$state_dir/had-docker-daemon-config" ]]; then
    install -m 0644 "$state_dir/docker-daemon.json" /etc/docker/daemon.json
  else
    rm -f -- /etc/docker/daemon.json
  fi
  systemctl daemon-reload
}

verify_running_set() {
  local state_dir="$1" container_id running health attempt health_attempts
  health_attempts="$(( (health_timeout_seconds + 4) / 5 ))"
  while IFS= read -r container_id; do
    [[ -n "$container_id" ]] || continue
    running="$(docker inspect --format '{{.State.Running}}' "$container_id")"
    [[ "$running" == "true" ]] || {
      printf 'ERROR: previously running container did not return: %s\n' "$container_id" >&2
      return 1
    }
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id")"
    if [[ -n "$health" ]]; then
      for ((attempt = 1; attempt <= health_attempts; attempt++)); do
        health="$(docker inspect --format '{{.State.Health.Status}}' "$container_id")"
        [[ "$health" == "healthy" ]] && break
        [[ "$attempt" -lt "$health_attempts" ]] || break
        sleep 5
      done
      [[ "$health" == "healthy" ]] || {
        printf 'ERROR: container health did not recover: %s (%s)\n' "$container_id" "$health" >&2
        return 1
      }
    fi
  done <"$state_dir/running-container-ids"
}

verify_migration() {
  local state_dir before_container_count after_container_count
  state_dir="$(readlink -f "$state_base/current")"
  [[ -d "$state_dir" ]] || { printf 'ERROR: migration state is missing.\n' >&2; exit 1; }
  check_mount
  systemctl is-active --quiet containerd docker k3s
  containerd config dump | rg '^root = ' | rg -q "$target_root"
  findmnt -rn -T "$target_root" -o TARGET | rg -q '^/mnt/ufiles$'
  verify_running_set "$state_dir"
  docker exec local-ollama ollama list >/dev/null
  k3s kubectl get nodes | rg -q ' Ready '
  k3s kubectl get pods -A --no-headers | awk '$4 != "Running" && $4 != "Completed" {exit 1}'
  before_container_count="$(( $(wc -l <"$state_dir/docker-ps.txt") - 1 ))"
  after_container_count="$(docker ps -aq | wc -l)"
  [[ "$after_container_count" == "$before_container_count" ]] || {
    printf 'ERROR: container count changed: before=%s after=%s\n' \
      "$before_container_count" "$after_container_count" >&2
    exit 1
  }
  docker ps -a --no-trunc >"$state_dir/docker-ps-after.txt"
  docker image ls --digests --no-trunc >"$state_dir/docker-images-after.txt"
  docker volume ls >"$state_dir/docker-volumes-after.txt"
  diff -u \
    <(awk 'NR > 1 {print $2}' "$state_dir/docker-volumes.txt" | sort) \
    <(docker volume ls -q | sort)
  date +%s >"$state_dir/verified-at-epoch"
  df -hT / /mnt/ufiles | tee "$state_dir/df-after.txt"
  printf 'Post-migration verification passed. Start the 24-hour soak.\n'
}

migrate() {
  preflight
  "$backup_ctl" preflight
  systemctl start osnova-backup.service
  "$backup_ctl" check-data

  local timestamp state_dir
  timestamp="$(date +%Y%m%dT%H%M%S)"
  state_dir="$state_base/$timestamp"
  install -d -m 0700 "$state_dir"
  docker ps -q >"$state_dir/running-container-ids"
  docker ps -a --no-trunc >"$state_dir/docker-ps.txt"
  docker image ls --digests --no-trunc >"$state_dir/docker-images.txt"
  docker volume ls >"$state_dir/docker-volumes.txt"
  df -hT / /mnt/ufiles >"$state_dir/df-before.txt"
  if [[ -f /etc/containerd/config.toml ]]; then
    install -m 0600 /etc/containerd/config.toml "$state_dir/containerd-config.toml"
    touch "$state_dir/had-containerd-config"
  fi
  if [[ -f /etc/systemd/system/containerd.service.d/20-osnova-storage.conf ]]; then
    install -m 0600 /etc/systemd/system/containerd.service.d/20-osnova-storage.conf \
      "$state_dir/containerd-storage.conf"
    touch "$state_dir/had-containerd-override"
  fi
  if [[ -f /etc/systemd/system/docker.service.d/10-storage-mounts.conf ]]; then
    install -m 0600 /etc/systemd/system/docker.service.d/10-storage-mounts.conf \
      "$state_dir/docker-storage-mounts.conf"
    touch "$state_dir/had-docker-storage-override"
  fi
  if [[ -f /etc/docker/daemon.json ]]; then
    install -m 0600 /etc/docker/daemon.json "$state_dir/docker-daemon.json"
    touch "$state_dir/had-docker-daemon-config"
  fi

  ansible-playbook -i "$repo_root/ansible/inventory.ini" \
    "$repo_root/ansible/container-runtime-storage.yml" \
    --check --diff -e container_runtime_apply=true

  mapfile -t running_ids <"$state_dir/running-container-ids"
  runtime_stopped=0
  recover_failed_migration() {
    local exit_status="$?"
    trap - EXIT
    if (( runtime_stopped == 1 )); then
      printf 'Migration failed during downtime; restoring original runtime.\n' >&2
      restore_original_runtime_config "$state_dir" || true
      systemctl start containerd.service docker.service || true
      restore_running_set "$state_dir" || true
    fi
    exit "$exit_status"
  }
  trap recover_failed_migration EXIT
  runtime_stopped=1
  if (( ${#running_ids[@]} > 0 )); then
    docker stop --time 60 "${running_ids[@]}"
  fi
  systemctl stop docker.socket docker.service
  systemctl stop containerd.service

  if findmnt -rn -R "$source_root" | rg -q .; then
    printf 'ERROR: active mounts remain under %s.\n' "$source_root" >&2
    exit 1
  fi

  install -d -m 0711 "$target_root"
  install -m 0600 /dev/null "$target_marker"
  rsync -aHAXS --numeric-ids --delete "$source_root/" "$target_root/"
  if rsync -aHAXS --numeric-ids --delete --dry-run "$source_root/" "$target_root/" | rg -q .; then
    printf 'ERROR: cold-copy verification found differences.\n' >&2
    exit 1
  fi

  ansible-playbook -i "$repo_root/ansible/inventory.ini" \
    "$repo_root/ansible/container-runtime-storage.yml" \
    -e container_runtime_apply=true
  systemctl start containerd.service docker.service
  restore_running_set "$state_dir"
  runtime_stopped=0
  trap - EXIT
  date +%s >"$state_dir/migrated-at-epoch"
  ln -sfn "$state_dir" "$state_base/current"

  sleep 10
  verify_migration
  printf 'Migration validated. Keep %s for 24 hours, then run --finalize.\n' "$source_root"
}

rollback() {
  local state_dir
  state_dir="$(readlink -f "$state_base/current")"
  [[ -d "$state_dir" ]] || { printf 'ERROR: migration state is missing.\n' >&2; exit 1; }
  systemctl stop docker.socket docker.service containerd.service
  restore_original_runtime_config "$state_dir"
  systemctl start containerd.service docker.service
  restore_running_set "$state_dir"
  printf 'Rollback completed using the original %s.\n' "$source_root"
}

finalize() {
  local state_dir migrated_at now
  state_dir="$(readlink -f "$state_base/current")"
  [[ -d "$state_dir" ]] || { printf 'ERROR: migration state is missing.\n' >&2; exit 1; }
  migrated_at="$(<"$state_dir/migrated-at-epoch")"
  now="$(date +%s)"
  (( now - migrated_at >= 86400 )) || { printf 'ERROR: 24-hour soak is not complete.\n' >&2; exit 1; }
  [[ "${CONFIRM_DELETE_OLD_CONTAINERD:-}" == "yes" ]] || {
    printf 'ERROR: set CONFIRM_DELETE_OLD_CONTAINERD=yes after explicit approval.\n' >&2
    exit 1
  }
  check_mount
  containerd config dump | rg '^root = ' | rg -q "$target_root"
  systemctl is-active --quiet docker containerd
  [[ -f "$target_marker" ]]
  if findmnt -rn -R "$source_root" | rg -q .; then
    printf 'ERROR: old containerd root still contains active mounts.\n' >&2
    exit 1
  fi
  [[ "$source_root" == "/var/lib/containerd" ]]
  rm -rf --one-file-system -- "$source_root"
  df -hT / /mnt/ufiles
  printf 'Old containerd root removed. Rollback now requires rsync from ufiles.\n'
}

require_root
case "$action" in
  --preflight) preflight ;;
  --migrate) migrate ;;
  --verify) verify_migration ;;
  --rollback) rollback ;;
  --finalize) finalize ;;
  *) usage; exit 2 ;;
esac
