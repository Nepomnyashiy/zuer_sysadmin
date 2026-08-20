#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/mnt/ufiles/backups"
KEEP_COUNT=2
MODE="dry-run"
REMOVE_UNCOMMITTED=false

usage() {
  cat <<'EOF'
Usage: prune-osnova-backups.sh [--dry-run|--apply] [--remove-uncommitted]

The latest symlink is the commit marker for the legacy full-copy backup.
Directories newer than latest are treated as uncommitted and are never removed
unless --remove-uncommitted is explicitly provided with --apply.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      ;;
    --apply)
      MODE="apply"
      ;;
    --remove-uncommitted)
      REMOVE_UNCOMMITTED=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d "$BACKUP_ROOT" ]] || ! mountpoint -q /mnt/ufiles; then
  printf 'ERROR: expected mounted backup root is unavailable: %s\n' "$BACKUP_ROOT" >&2
  exit 1
fi

LATEST_TARGET="$(readlink -f -- "$BACKUP_ROOT/latest")"
case "$LATEST_TARGET" in
  "$BACKUP_ROOT"/????-??-??_??-??-??)
    ;;
  *)
    printf 'ERROR: latest does not resolve to a valid backup directory: %s\n' "$LATEST_TARGET" >&2
    exit 1
    ;;
esac
[[ -d "$LATEST_TARGET" ]] || {
  printf 'ERROR: latest target does not exist: %s\n' "$LATEST_TARGET" >&2
  exit 1
}
LATEST_NAME="${LATEST_TARGET##*/}"

mapfile -t ALL_BACKUPS < <(
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
    -name '????-??-??_??-??-??' -printf '%f\n' \
    | LC_ALL=C sort -r
)

COMMITTED=()
UNCOMMITTED=()
found_latest=false
for backup_name in "${ALL_BACKUPS[@]}"; do
  if [[ "$backup_name" == "$LATEST_NAME" ]]; then
    found_latest=true
  fi
  if [[ "$found_latest" == true ]]; then
    COMMITTED+=("$backup_name")
  else
    UNCOMMITTED+=("$backup_name")
  fi
done

[[ "$found_latest" == true ]] || {
  printf 'ERROR: latest target is not present in the backup inventory: %s\n' "$LATEST_NAME" >&2
  exit 1
}

keep_count="$KEEP_COUNT"
if (( ${#COMMITTED[@]} < keep_count )); then
  keep_count="${#COMMITTED[@]}"
fi
KEEP=("${COMMITTED[@]:0:keep_count}")
EXPIRED=("${COMMITTED[@]:keep_count}")

printf 'Committed backups to keep (%d):\n' "${#KEEP[@]}"
if (( ${#KEEP[@]} > 0 )); then
  printf '  %s\n' "${KEEP[@]}"
fi
printf 'Committed backups to remove (%d):\n' "${#EXPIRED[@]}"
if (( ${#EXPIRED[@]} > 0 )); then
  printf '  %s\n' "${EXPIRED[@]}"
fi
printf 'Uncommitted backup candidates newer than latest (%d):\n' "${#UNCOMMITTED[@]}"
if (( ${#UNCOMMITTED[@]} > 0 )); then
  printf '  %s\n' "${UNCOMMITTED[@]}"
fi

if [[ "$MODE" == "dry-run" ]]; then
  printf 'Dry-run only. No directories were removed.\n'
  if (( ${#UNCOMMITTED[@]} > 0 )); then
    printf 'Verify journal evidence before using --apply --remove-uncommitted.\n'
  fi
  exit 0
fi

if (( EUID != 0 )); then
  printf 'ERROR: --apply must be run as root.\n' >&2
  exit 1
fi

if systemctl is-active --quiet osnova-backup.service; then
  printf 'ERROR: osnova-backup.service is active; refusing concurrent cleanup.\n' >&2
  exit 1
fi

if (( ${#UNCOMMITTED[@]} > 0 )) && [[ "$REMOVE_UNCOMMITTED" != true ]]; then
  printf 'ERROR: uncommitted directories exist; verify them and pass --remove-uncommitted explicitly.\n' >&2
  exit 1
fi

REMOVE=("${EXPIRED[@]}")
if [[ "$REMOVE_UNCOMMITTED" == true ]]; then
  REMOVE+=("${UNCOMMITTED[@]}")
fi

for backup_name in "${REMOVE[@]}"; do
  target="$BACKUP_ROOT/$backup_name"
  printf 'Removing %s\n' "$target"
  rm -rf --one-file-system -- "$target"
done

printf 'Cleanup completed. Remaining filesystem usage:\n'
df -hT /mnt/ufiles
