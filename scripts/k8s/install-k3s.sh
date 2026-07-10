#!/usr/bin/env bash
set -euo pipefail

mode="apply"
if [[ "${1:-}" == "--check" ]]; then
  mode="check"
fi

K3S_CHANNEL="${K3S_CHANNEL:-stable}"
K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"
K3S_CONFIG_DIR="${K3S_CONFIG_DIR:-/etc/rancher/k3s}"
K3S_CONFIG_FILE="${K3S_CONFIG_FILE:-$K3S_CONFIG_DIR/config.yaml}"
K3S_REGISTRIES_FILE="${K3S_REGISTRIES_FILE:-$K3S_CONFIG_DIR/registries.yaml}"
LOCAL_PATH_ROOT="${LOCAL_PATH_ROOT:-/mnt/ufiles/k8s/local-path}"

cat <<EOF
Mode: $mode
K3S_CHANNEL: $K3S_CHANNEL
K3S_CONFIG_FILE: $K3S_CONFIG_FILE
K3S_REGISTRIES_FILE: $K3S_REGISTRIES_FILE
LOCAL_PATH_ROOT: $LOCAL_PATH_ROOT

Planned k3s options:
  disable:
    - traefik
    - servicelb
  write-kubeconfig-mode: "0644"
  default-local-storage-path: "$LOCAL_PATH_ROOT"
EOF

if [[ "$mode" == "check" ]]; then
  echo
  echo "Check mode only. No host changes were made."
  echo "Before apply, verify Docker Traefik still owns 80/443 and /mnt/ufiles is rw."
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./scripts/k8s/install-k3s.sh" >&2
  exit 1
fi

mkdir -p "$K3S_CONFIG_DIR" "$LOCAL_PATH_ROOT"

cat >"$K3S_CONFIG_FILE" <<EOF
disable:
  - traefik
  - servicelb
write-kubeconfig-mode: "0644"
default-local-storage-path: "$LOCAL_PATH_ROOT"
EOF

cat >"$K3S_REGISTRIES_FILE" <<EOF
mirrors:
  "127.0.0.1:30500":
    endpoint:
      - "http://127.0.0.1:30500"
configs:
  "127.0.0.1:30500":
    tls:
      insecure_skip_verify: true
EOF

curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL="$K3S_CHANNEL" sh -

systemctl status k3s --no-pager
kubectl get nodes -o wide

echo "k3s installed. Kubeconfig: /etc/rancher/k3s/k3s.yaml"
