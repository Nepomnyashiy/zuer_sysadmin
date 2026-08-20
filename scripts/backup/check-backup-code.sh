#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
TMP_DIR="$(mktemp -d /tmp/osnova-backup-check.XXXXXX)"

cleanup() {
  rm -rf --one-file-system -- "$TMP_DIR"
}
trap cleanup EXIT

cd "$REPO_ROOT"

render_template() {
  local template="$1"
  local output="$2"
  ansible localhost -c local -m ansible.builtin.template \
    -a "src=$template dest=$output" \
    -e @ansible/group_vars/all.yml \
    -e ansible_become=false >/dev/null
}

render_template ansible/templates/osnova-backup.sh.j2 "$TMP_DIR/osnova-backup.sh"
render_template ansible/templates/osnova-backupctl.sh.j2 "$TMP_DIR/osnova-backupctl"
render_template ansible/templates/osnova-restic.env.j2 "$TMP_DIR/restic.env"

for unit in \
  osnova-backup.service \
  osnova-backup.timer \
  osnova-backup-maintenance@.service \
  osnova-backup-prune.timer \
  osnova-backup-check.timer \
  osnova-backup-check-data.timer; do
  render_template "ansible/templates/$unit.j2" "$TMP_DIR/$unit"
done

bash -n "$TMP_DIR/osnova-backup.sh"
bash -n "$TMP_DIR/osnova-backupctl"
bash -n scripts/backup/prune-osnova-backups.sh

if rg -n 'df -P --output' "$TMP_DIR/osnova-backup.sh" "$TMP_DIR/osnova-backupctl"; then
  printf 'ERROR: GNU df rejects using -P together with --output\n' >&2
  exit 1
fi

if rg -n 'findmnt .* -o OPTIONS|mount_options' \
  "$TMP_DIR/osnova-backup.sh" "$TMP_DIR/osnova-backupctl"; then
  printf 'ERROR: mount OPTIONS are misleading inside ProtectSystem=strict units\n' >&2
  exit 1
fi

for rendered_script in "$TMP_DIR/osnova-backup.sh" "$TMP_DIR/osnova-backupctl"; do
  if ! rg -q '\.osnova-write-test\.' "$rendered_script"; then
    printf 'ERROR: %s lacks a real repository write probe\n' "$rendered_script" >&2
    exit 1
  fi
done

used_percent="$(df --output=pcent / | awk 'NR == 2 { gsub(/%/, "", $1); print $1; exit }')"
if [[ ! "$used_percent" =~ ^[0-9]+$ ]] || (( used_percent < 0 || used_percent > 100 )); then
  printf 'ERROR: free-space parser returned an invalid value: %s\n' "$used_percent" >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$TMP_DIR/osnova-backup.sh" "$TMP_DIR/osnova-backupctl" \
    scripts/backup/prune-osnova-backups.sh
fi

systemd-analyze calendar '*-*-* 03:20:00' >/dev/null
systemd-analyze calendar 'Sun *-*-* 05:15:00' >/dev/null
systemd-analyze calendar 'Sat *-*-* 05:15:00' >/dev/null
systemd-analyze calendar 'Sun *-*-01..07 06:30:00' >/dev/null

verify_status=0
systemd-analyze verify "$TMP_DIR"/*.service "$TMP_DIR"/*.timer \
  2>"$TMP_DIR/systemd-verify.err" || verify_status=$?
if (( verify_status != 0 )); then
  rg -v \
    'Failed to (turn off SO_PASSRIGHTS on user lookup socket|enable SO_PASSCRED on handoff timestamp socket)' \
    "$TMP_DIR/systemd-verify.err" >"$TMP_DIR/systemd-verify.filtered" || true
  if [[ -s "$TMP_DIR/systemd-verify.filtered" ]]; then
    cat "$TMP_DIR/systemd-verify.filtered" >&2
    exit 1
  fi
fi

if rg -n '\{%|%\}|\{\{ backup_|\{\{ ufiles_|\{\{ expected_' \
  "$TMP_DIR"; then
  printf 'ERROR: rendered templates contain unresolved Jinja expressions\n' >&2
  exit 1
fi

printf 'Backup code validation passed.\n'
