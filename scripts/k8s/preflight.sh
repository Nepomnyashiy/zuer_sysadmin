#!/usr/bin/env bash
set -euo pipefail

failures=0

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    info "$name: $(command -v "$name")"
  else
    warn "$name not found"
  fi
}

check_mount_rw() {
  local target="$1"
  if ! findmnt -T "$target" >/dev/null 2>&1; then
    fail "$target is not mounted"
    return
  fi

  local line
  line="$(findmnt -T "$target" -no TARGET,SOURCE,FSTYPE,OPTIONS)"
  info "$line"

  if [[ "$line" == *",ro,"* || "$line" == *" ro,"* || "$line" == *",ro" ]]; then
    fail "$target is read-only"
  fi
}

check_port() {
  local port="$1"
  local output
  if ! output="$(ss -ltn "( sport = :$port )" 2>&1)"; then
    warn "cannot inspect tcp/$port: $output"
    return
  fi

  if printf '%s\n' "$output" | tail -n +2 | grep -q .; then
    info "tcp/$port is listening"
  else
    warn "tcp/$port is not listening"
  fi
}

info "Host: $(hostname)"
info "Kernel: $(uname -r)"
info "Date: $(date -Is)"

info "Checking commands"
check_command docker
check_command kubectl
check_command helm
check_command kustomize
check_command k3s
check_command ansible-playbook
check_command nvidia-smi

info "Checking CPU and memory"
lscpu | sed -n '1,12p'
free -h

info "Checking storage"
df -h / /mnt/ufiles /run/media/nsadmin/godny_soft 2>/dev/null || true
check_mount_rw /mnt/ufiles
check_mount_rw /run/media/nsadmin/godny_soft

info "Checking existing edge ports"
check_port 22
check_port 80
check_port 443
check_port 30080
check_port 30443
check_port 30500

info "Checking Docker access"
if docker ps >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
else
  warn "docker ps failed; run from a user with Docker access or use sudo"
fi

info "Checking GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
  else
    warn "nvidia-smi exists but cannot communicate with NVIDIA driver"
  fi
else
  warn "nvidia-smi not installed; do not move Ollama to Kubernetes yet"
fi

if (( failures > 0 )); then
  fail "Preflight finished with $failures blocking failure(s)"
  exit 1
fi

info "Preflight finished without blocking failures"
