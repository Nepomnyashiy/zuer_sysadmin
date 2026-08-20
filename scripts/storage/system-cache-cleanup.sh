#!/usr/bin/env bash
set -euo pipefail

mode="${1:---plan}"
if [[ "$mode" != "--plan" && "$mode" != "--apply" ]]; then
  printf 'Usage: %s [--plan|--apply]\n' "$0" >&2
  exit 2
fi

printf 'Journal usage:\n'
journalctl --disk-usage
printf '\nAPT cache usage:\n'
du -sh /var/cache/apt 2>/dev/null || true
printf '\nDisabled Snap revisions:\n'
if ! snap_inventory="$(timeout 30 env LC_ALL=C snap list --all)"; then
  printf 'ERROR: snapd inventory did not complete within 30 seconds.\n' >&2
  exit 1
fi
mapfile -t disabled_snaps < <(
  awk 'NR > 1 && index($NF, "disabled") {print $1 " " $3}' <<<"$snap_inventory"
)
if (( ${#disabled_snaps[@]} == 0 )); then
  printf 'none\n'
else
  printf '%s\n' "${disabled_snaps[@]}"
fi

if [[ "$mode" == "--plan" ]]; then
  printf '\nPlan only: target journal size is 300M; active Snap revisions are excluded.\n'
  exit 0
fi
if (( EUID != 0 )); then
  printf 'ERROR: run apply as root.\n' >&2
  exit 1
fi

for snap_record in "${disabled_snaps[@]}"; do
  read -r snap_name snap_revision <<<"$snap_record"
  snap remove "$snap_name" --revision="$snap_revision"
done
journalctl --vacuum-size=300M
apt-get clean

printf '\nAfter cleanup:\n'
journalctl --disk-usage
du -sh /var/cache/apt 2>/dev/null || true
df -hT /
