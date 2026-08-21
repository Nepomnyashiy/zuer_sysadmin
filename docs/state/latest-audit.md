# ZUER Latest Audit

**Status:** OK

**Updated:** 2026-08-21T10:19:00+03:00

**Scope:** полный live startup audit по `skills/system-startup/SKILL.md`

## Итог

ZUER готов к продолжению platform validation и подготовке Kolos/Anaconda.
Блокирующих ошибок хоста, Docker или Kubernetes не обнаружено. Single-node
кластер не является отказоустойчивым; stateful deployment всё равно требует
проверенного backup/restore и отдельного migration plan.

## Host

- Hostname: `ZUER`.
- OS: Ubuntu 26.04 LTS.
- Kernel: `7.0.0-29-generic`.
- Uptime на момент проверки: 2 дня.
- Load average: `0.99 / 1.03 / 1.14`.
- systemd failed units: `0`.

## Compute

- CPU: Intel Core i5-12600KF, 10 cores / 16 logical CPUs.
- RAM: 30 GiB total, 8.9 GiB used, 21 GiB available.
- Swap: 8 GiB total, 4.8 MiB used.
- GPU: NVIDIA GeForce RTX 4060, driver `595.84`, CUDA `13.2`.
- VRAM: 531 MiB / 8188 MiB; GPU utilization 0-7% во время аудита.

## Storage и mounts

| Mount | Filesystem | Usage | Available | State |
| --- | --- | ---: | ---: | --- |
| `/` | ext4 | 67% | 35 GiB | `rw` |
| `/mnt/ufiles` | ext4 | 31% | 605 GiB | `rw` |
| `/run/media/nsadmin/godny_soft` | ext4 | 6% | 196 GiB | `rw` |
| `/srv/storage/x-files` | NTFS/fuseblk | 59% | 775 GiB | mounted |
| `/srv/storage/mega-files` | NTFS/fuseblk | 55% | 848 GiB | mounted |

Inode pressure не обнаружен. k3s local-path настроен на
`/mnt/ufiles/k8s/local-path`; registry PV физически расположен там же.

## Network и edge ports

- LAN: `192.168.0.101/24` на `enp4s0`.
- Default route: `192.168.0.1` через `enp4s0`.
- Flannel/CNI: `10.42.0.0/24`; Service CIDR: `10.43.0.0/16`.
- Docker Traefik занимает host `80/443`, как предусмотрено архитектурой.
- SSH слушает `22`; XRDP слушает `3389` и должен оставаться ограничен
  firewall/LAN/VPN политикой.
- Базы и internal AI endpoints привязаны к localhost или внутренним Docker
  networks; публичных PostgreSQL/Redis sockets не найдено.

NodePort не обязан отображаться как userspace listening socket в `ss`, потому
что трафик обрабатывается kube-proxy/iptables. Функциональная проверка:

- `http://127.0.0.1:30080/` -> HTTP `404` от ingress-nginx;
- `https://127.0.0.1:30443/` -> HTTPS `404` от ingress-nginx;
- `http://127.0.0.1:30500/v2/` -> HTTP `200` от registry.

## Docker

- Docker Engine: `29.1.3`; containerd image store активен.
- Running containers: 13, включая Traefik, Nextcloud, PromBizTech web,
  локальные AI-сервисы и внутренние базы.
- Docker storage: 31.99 GB images, из них 23.93 GB помечено reclaimable;
  cleanup не выполнялся.
- Traefik продолжает владеть `80/443`.

## k3s / Kubernetes

- k3s/Kubernetes: `v1.36.2+k3s1`.
- k3s service: enabled, active since 2026-08-19 10:01 MSK.
- Node `zuer`: `Ready`; MemoryPressure, DiskPressure и PIDPressure — `False`.
- Container runtime: `containerd://2.3.2-k3s2`.
- Metrics API работает.
- Kubernetes events на момент проверки отсутствовали.

Workloads:

- 5/5 infrastructure Pods `Running` и `Ready`;
- ingress-nginx, local-registry, CoreDNS, local-path-provisioner и
  metrics-server доступны;
- application namespaces `anaconda`, `barber`, `kolos`, `ai-platform`,
  `monitoring`, `databases` существуют, но application workloads пока не
  развёрнуты;
- у инфраструктурных Pods по 21 restart, последний был 2 дня назад вместе с
  текущим boot; текущих restart loops нет.

## Ingress и registry

- ingress-nginx controller: `1/1 Ready`.
- Service: NodePort `30080/30443` с endpoint `10.42.0.115:80/443`.
- Local registry: `1/1 Ready`, NodePort `30500`, API `/v2/` отвечает `200`.
- Ingress resources приложений пока отсутствуют.

## Docker Traefik -> Kubernetes

- Traefik работает в Docker network `proxy`, container IP `172.19.0.8`,
  gateway `172.19.0.1`.
- Из контейнера Traefik `http://192.168.0.101:30080/` доступен и возвращает
  ожидаемый ingress-nginx `404`, пока app Ingress отсутствуют.
- Upstream `127.0.0.1:30080` из Traefik использовать нельзя: loopback внутри
  контейнера не является loopback хоста.
- Live host rules: `cloud.godny.tech`, `traefik.godny.tech`, `ai.godny.tech`,
  `llm.godny.tech`, `prombiz.godny.tech`, `prombiz.tech` и `www.prombiz.tech`.
- Live rules для `agro.godny.tech`, `api.agro.godny.tech`,
  `anaconda.godny.tech`, `api.anaconda.godny.tech` отсутствуют; конфликтов с
  существующими routes не обнаружено.
- `cloud.godny.tech` отвечает ожидаемым `302` на `/login`, Traefik dashboard —
  ожидаемым `401` без credentials.

## DNS

System resolver и `1.1.1.1` возвращают одинаковые данные:

| Host | A | AAAA | CNAME |
| --- | --- | --- | --- |
| `agro.godny.tech` | `85.172.104.173` | нет | нет |
| `api.agro.godny.tech` | `85.172.104.173` | нет | нет |
| `anaconda.godny.tech` | `85.172.104.173` | нет | нет |
| `api.anaconda.godny.tech` | `85.172.104.173` | нет | нет |

## PV / PVC / StorageClass

- `osnova-local-retain`: provisioner `rancher.io/local-path`,
  `reclaimPolicy: Retain`, `WaitForFirstConsumer`.
- Registry PVC `ingress/local-registry-data`: `Bound`, 20 GiB, RWO.
- Registry PV: `Bound`, `Retain`, физический path:
  `/mnt/ufiles/k8s/local-path/pvc-f605ff12-4003-47ba-b9b3-628406e93fef_ingress_local-registry-data`.
- Других PV/PVC пока нет.

## Capacity

- Node allocatable: 16 CPU, 31,906,288 Ki memory, 110 Pods.
- Kubernetes requests: 400m CPU (2%), 524 MiB memory (1%).
- Kubernetes limits: 1500m CPU (9%), 1450 MiB memory (4%).
- Текущее node usage: около 556m CPU (3%) и 8494 MiB memory (27%).

Предварительно capacity достаточно для запуска Kolos и Anaconda с безопасными
стартовыми requests/limits. Окончательное подтверждение требуется после аудита
их Compose/Dockerfile, production data и фактических resource profiles.

## Backup и предупреждения

- В текущем boot были две восстановленные ошибки backup: `No space left on
  device` и временный `read-only` для `/mnt/ufiles` 2026-08-20.
- Последний запуск `osnova-backup.service` завершился успешно 2026-08-21
  03:39 MSK: `Result=success`, `ExecMainStatus=0`.
- Четыре backup timers активны; следующий daily запуск запланирован на
  2026-08-22.
- Root filesystem уже использует 67%; следить за ростом build artifacts и
  container images.
- Docker показывает 23.93 GB reclaimable images. Автоматический prune не
  выполнялся, поскольку cleanup требует отдельной оценки используемых tags и
  rollback-образов.
- GPU доступна, но перенос Black Mamba/Ollama по-прежнему требует отдельного
  GPU preflight согласно проектным правилам.

## Выполненные проверки

- host identity, OS/kernel/uptime, CPU, RAM/swap, GPU;
- `df`, inode usage, `findmnt`, network addresses/routes, listening ports;
- Docker containers и storage usage;
- k3s systemd status и critical journal;
- nodes, namespaces, Pods, controllers, Services, Ingress, events и metrics;
- PV/PVC/StorageClass и physical registry PV path;
- ingress NodePort и registry functional curl checks;
- `make k8s-preflight` и `make k8s-status`.

## Следующий безопасный шаг

Phase 3: проверить декларативную и фактическую цепочку Docker Traefik ->
NodePort -> ingress-nginx, текущие routes и отсутствие конфликтов с
существующими public services. Затем выполнить DNS validation.

## Rollback

Аудит был read-only; runtime не изменялся. Для этого этапа rollback не нужен.
