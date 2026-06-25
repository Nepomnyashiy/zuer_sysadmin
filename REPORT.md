# Server Audit and Preparation Report

Date: 2026-06-25

## Executive Summary

The host is a fresh Ubuntu 26.04 LTS installation intended to become the main
server for commercial web applications, SSH access, remote desktop, and file
storage. The current state is not yet production-ready: OpenSSH server, Docker,
Ansible, XRDP, and the final storage mounts are not configured as a managed
baseline.

The immediate target is a safe bootstrap layer: packages, SSH hardening,
firewall, storage mountpoints, Nextcloud scaffolding, RDP over trusted access,
and backups.

## Current Facts

- OS: Ubuntu 26.04 LTS, kernel `7.0.0-22-generic`.
- Main user: `nsadmin`.
- Project disk: `/dev/sdb1` mounted at `/run/media/nsadmin/godny_soft`.
- Root disk: `/dev/sdc2`, ext4, mounted at `/`.
- Backup disk: `/dev/sdf1`, label `ufiles`, ext4, UUID
  `548a00f5-dfd3-47d0-9879-b2a175b5bdb1`, currently not mounted.
- Storage disk: `/dev/sdd2`, label `X-FILES`, NTFS, UUID
  `2800B35C00B33024`, currently not mounted.
- Storage disk: `/dev/sde1`, label `MEGA FILES`, NTFS, UUID
  `18B0DD66B0DD4AC0`, currently not mounted.
- `openssh-server`: not installed.
- `/home/nsadmin/.ssh/authorized_keys`: exists, mode `600`, but currently empty.
- `docker.io`: not installed.
- `ansible`: not installed.
- `ufw`: installed.
- `unattended-upgrades`: installed.
- `nodejs`: installed.
- `npm`: installed.
- Hiddify: installed as a user application, not as a server-managed routing
  service.

## Project Inventory

- `soft/gigavpn`: Go backend, Python bot, PostgreSQL, Prometheus/Grafana.
  Current compose exposes PostgreSQL, API, Prometheus, and Grafana ports.
- `bratusin/kolos_web`: Strapi/PostgreSQL/Next.js. Current compose exposes
  backend and frontend ports and uses default database fallback credentials.
- `site/anaconda_site`: Vite/React site, requires Gemini API key.
- `soft/kip-service/anaconda_mvp`: FastAPI/Vue/PostgreSQL. Current compose
  exposes PostgreSQL and API ports, and contains demo credentials.
- `soft/black_mamba`: local LLM/RAG platform. Mostly binds to `127.0.0.1`, but
  contains local secrets and model storage assumptions.
- `soft/devops-lab`: lab stack. Not production-ready by default because it
  exposes monitoring/admin services with demo credentials.
- `soft/codex_node_agent`: early-stage service with example secrets.

## Security Findings

- Multiple `.env` files and key files exist under project directories.
- Several secret files have mode `664`; target mode is `600`.
- SSH key-only hardening cannot be enabled until a real client public key is
  added to `/home/nsadmin/.ssh/authorized_keys`.
- Several compose files publish databases or admin panels to host ports.
- Multiple services conflict on common ports such as `3000`, `8080`, and `9090`.
- RDP must not be exposed directly to the internet.
- Docker can bypass UFW rules if ports are published without deliberate binding
  and firewall design.

## Storage Plan

- `/mnt/ufiles`: backup and server data mount.
- `/srv/storage/x-files`: NTFS disk for file storage.
- `/srv/storage/mega-files`: NTFS disk for file storage.
- Nextcloud will provide the web interface.
- Nextcloud External Storage will expose `x-files` and `mega-files`.
- No formatting is allowed during bootstrap.

## Network Plan

- Incoming services remain reachable through:
  - IPv4: `85.172.104.173`
  - IPv6: `2a13:7c00:10:26:f816:3eff:fe99:a89e`
- UFW default: deny incoming, allow outgoing.
- SSH, HTTP, HTTPS, and explicit project ports are allowed.
- Databases and admin panels are local/trusted-network only.
- Hiddify can be used for outgoing CLI/proxy traffic, but bootstrap must not
  change the default route or TUN policy routing automatically.

## Bootstrap Deliverables

- `CODEX.md`: operating rules for future Codex/admin work.
- `ansible/bootstrap.yml`: safe host bootstrap playbook.
- `ansible/group_vars/all.yml`: central variables and required secrets.
- `ansible/templates/*`: managed service and config templates.
- `ansible/README.md`: usage and safety instructions.

## Immediate Blockers Before Applying

- Add SSH public key to `/home/nsadmin/.ssh/authorized_keys`.
- Put Nextcloud secrets in Ansible Vault or root-only variables.
- Decide explicit `public_tcp_ports` for project ports that must be reachable
  from the internet.
