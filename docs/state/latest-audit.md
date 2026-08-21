# ZUER Latest Audit

**Status:** NOT YET REFRESHED BY LIVE AGENT  
**Updated:** 2026-08-21

Этот файл предназначен для фактического состояния сервера ZUER, собранного агентом непосредственно на сервере.

Не считать данные из старых отчётов достаточными для текущего deployment без live delta-check.

## Required output

После запуска свежего агента сюда должны быть записаны без секретов:

- timestamp;
- hostname / OS / kernel / uptime;
- CPU/load;
- RAM/swap;
- GPU/VRAM;
- storage и mount status;
- Docker/containerd;
- k3s/node state;
- Pods/Deployments/StatefulSets;
- ingress-nginx;
- local registry;
- PV/PVC/StorageClass;
- critical systemd failures;
- critical errors/warnings;
- available capacity;
- итоговый статус `OK`, `DEGRADED` или `CRITICAL`.
