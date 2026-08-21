# CURRENT — Развёртывание и стандартизация приложений на godny.tech

**Status:** ACTIVE  
**Server:** ZUER  
**Priority:** HIGH  
**Created:** 2026-08-21

## Цель

Стандартизировать deployment приложений OSNOVA/GodnySoft на существующей Kubernetes-платформе ZUER и довести до стабильной публичной работы:

- Kolos: `https://agro.godny.tech`
- Kolos API: `https://api.agro.godny.tech`
- Anaconda: `https://anaconda.godny.tech`
- Anaconda API: `https://api.anaconda.godny.tech`

После deployment интегрировать сервисы и Kubernetes с существующей **PromBizTech Analytics Platform** и сформировать единый стандарт для следующих приложений.

## Архитектурные ограничения

Текущий edge сохраняется:

```text
Internet
-> router 80/443
-> Docker Traefik
-> ingress-nginx NodePort 30080/30443
-> Kubernetes Ingress
-> ClusterIP Service
-> Pod
```

Не заменять Docker Traefik и не занимать Kubernetes'ом host ports 80/443.

Local registry:

```text
127.0.0.1:30500
```

StorageClass:

```text
osnova-local-retain
```

PostgreSQL наружу не публикуется.

## Phase 1 — Agent/repository standardization

- [x] Создать ветку `agent/sysadmin`.
- [x] Создать `skills/README.md`.
- [x] Добавить system startup skill.
- [x] Добавить Kubernetes skill.
- [x] Добавить DevOps skill.
- [x] Добавить application deployment skill.
- [x] Добавить monitoring/observability skill.
- [x] Добавить incident diagnostics skill.
- [x] Добавить documentation sync skill.
- [x] Добавить secrets management skill.
- [x] Добавить компактный `docs/agent/START_PROMPT.md`.
- [x] Создать текущую task-модель.
- [ ] При необходимости синхронизировать ссылки на новую структуру с `AGENTS.md`/`README.md` без дублирования больших инструкций.

## Phase 2 — ZUER audit

Провести стартовый аудит согласно `skills/system-startup/SKILL.md`.

Сохранить фактический результат в:

```text
docs/state/latest-audit.md
```

Проверить:

- [x] OS/kernel/uptime.
- [x] CPU/load.
- [x] RAM/swap.
- [x] GPU/VRAM.
- [x] root и data storage.
- [x] mountpoints и ro/rw.
- [x] network/routes/listening ports.
- [x] Docker/containerd.
- [x] k3s/node state.
- [x] namespaces/pods/deployments/statefulsets.
- [x] ingress-nginx.
- [x] registry 30500.
- [x] PV/PVC/StorageClass.
- [x] systemd failures.
- [x] доступный capacity для Kolos + Anaconda.

Результат 2026-08-21: `OK`. Полный snapshot сохранён в
`docs/state/latest-audit.md`, ход-отчёт — в
`docs/reports/2026-08-21-zuer-startup-audit.md`. Блокирующих проблем нет;
root filesystem использует 67%, Docker показывает 23.93 GB reclaimable images,
cleanup не выполнялся. Последний backup завершён успешно после двух
восстановленных ошибок 2026-08-20.

## Phase 3 — Platform validation

Проверить фактическую цепочку:

```text
Docker Traefik -> 127.0.0.1:30080 -> ingress-nginx -> app Ingress
```

- [x] ingress-nginx healthy.
- [x] NodePort 30080 работает.
- [x] NodePort 30443 работает.
- [x] registry `127.0.0.1:30500` доступен.
- [x] `osnova-local-retain` существует и пригоден для stateful workloads.
- [x] существующие public services не конфликтуют.

Результат 2026-08-21: Traefik container достигает ingress-nginx через
`http://192.168.0.101:30080`; ответ `404` ожидаем до появления app Ingress.
`127.0.0.1:30080` нельзя использовать как upstream из Docker-контейнера без
host networking, потому что loopback относится к самому контейнеру. В live
Traefik нет rules для целевых Kolos/Anaconda hosts, существующие routes не
конфликтуют.

## Phase 4 — DNS

Проверить:

```text
agro.godny.tech
api.agro.godny.tech
anaconda.godny.tech
api.anaconda.godny.tech
```

Ожидаемый public IPv4:

```text
85.172.104.173
```

- [x] agro DNS.
- [x] api.agro DNS.
- [x] anaconda DNS.
- [x] api.anaconda DNS.

Результат 2026-08-21: system resolver и `1.1.1.1` возвращают
`85.172.104.173` для всех четырёх A-записей. AAAA и CNAME не опубликованы.

## Phase 5 — Anaconda deployment

Source:

```text
/run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp
```

Kubernetes manifests:

```text
apps/anaconda/k8s
```

Проверить:

- [x] Docker build contexts.
- [x] ConfigMap.
- [x] Secret mapping без вывода secret values.
- [x] frontend.
- [x] FastAPI API.
- [x] PostgreSQL.
- [x] probes.
- [x] resource requests/limits.
- [x] PVC/stateful data.
- [x] Ingress hosts.

Использовать существующий workflow:

```bash
./scripts/k8s/create-secret-from-env.sh \
  anaconda \
  anaconda-secret \
  /run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp/.env \
  POSTGRES_PASSWORD \
  TELEGRAM_BOT_TOKEN \
  EMAIL_IMAP_USER \
  EMAIL_IMAP_PASSWORD

make app-build APP=anaconda IMAGE_TAG=git-aeef02d
make app-push APP=anaconda IMAGE_TAG=git-aeef02d
make app-dry-run APP=anaconda
make app-diff APP=anaconda
make app-apply APP=anaconda
```

Pre-deployment результат 2026-08-21:

- source hardening: ветка `agent/anaconda-k8s-readiness`, commits `fdc178d` и
  `aeef02d`;
- frontend переведён с Vite dev server на static Nginx `8080`;
- API имеет `/live` и DB-aware `/ready`, не логирует token prefix;
- current-tree credential literals удалены, npm audit: 0 vulnerabilities;
- существующие Anaconda Docker containers/volumes не найдены, первый rollout
  создаёт новую пустую PostgreSQL;
- immutable API/web images `git-aeef02d` опубликованы в local registry и
  зафиксированы в manifests по OCI digest;
- server-side dry-run успешен, diff показывает создание ожидаемых resources;
- backup/restore runbook и smoke script добавлены.

### Phase 5A — Secrets hygiene gate

До фактического Anaconda apply выполнить отдельную focused task:

```text
tasks/SECRETS_HYGIENE.md
```

Обязательные документы:

```text
skills/secrets-management/SKILL.md
docs/runbooks/secrets-management.md
```

Текущий стандарт:

```text
Git -> обычная конфигурация + encrypted Ansible Vault
ZUER -> local .env только как gitignored bootstrap/runtime source
Ansible Vault -> allowlisted Kubernetes Secret -> Pod
```

Текущее решение пользователя для тестового этапа:

- [ ] не ротировать существующие Telegram/IMAP credentials;
- [ ] удалить plaintext credentials из relevant Git history;
- [ ] убедиться, что `.env` не tracked и имеет безопасные права;
- [ ] создать/проверить encrypted Ansible Vault source of truth;
- [ ] хранить vault password вне Git;
- [ ] использовать allowlisted Kubernetes Secret workflow;
- [ ] повторно выполнить secret scan current tree + rewritten history;
- [ ] обновить старые source commit SHA в sysadmin docs после history rewrite;
- [ ] завершить `tasks/SECRETS_HYGIENE.md` статусом `READY`.

Residual risk принят пользователем для тестового этапа: history rewrite не гарантирует удаления уже скопированного секрета из сторонних clones/forks/caches. Перед реальным production использованием такие credentials должны быть перевыпущены.

После статуса `SECRETS HYGIENE: READY` основной deployment-agent синхронизирует `agent/sysadmin`, читает обновлённый task state и продолжает Anaconda rollout без повторения уже завершённого platform-аудита.

После rollout:

- [ ] required Pods Ready.
- [ ] PostgreSQL healthy.
- [ ] PVC Bound.
- [ ] internal Service works.
- [ ] Kubernetes Ingress works.
- [ ] `https://anaconda.godny.tech` works.
- [ ] `https://api.anaconda.godny.tech` works.

## Phase 6 — Kolos deployment

Source:

```text
/run/media/nsadmin/godny_soft/soft/kolos_web
```

Kubernetes manifests:

```text
apps/kolos/k8s
```

Домены сохраняются:

```text
https://agro.godny.tech
https://api.agro.godny.tech
```

Не переименовывать в `kolos.godny.tech`.

Перед deployment определить фактический источник production data:

- [ ] текущая PostgreSQL.
- [ ] текущие Strapi uploads.
- [ ] существующий backup.
- [ ] restore procedure.
- [ ] migration/rollback plan.

Не заменять рабочую БД пустой.

Проверить:

- [ ] Next.js frontend.
- [ ] Strapi backend.
- [ ] PostgreSQL StatefulSet.
- [ ] uploads PVC.
- [ ] ConfigMap/Secret.
- [ ] probes.
- [ ] requests/limits.
- [ ] Ingress.

Workflow:

```bash
./scripts/k8s/create-secret-from-env.sh \
  kolos \
  kolos-secret \
  /run/media/nsadmin/godny_soft/soft/kolos_web/.env

make app-build APP=kolos
make app-push APP=kolos
make app-dry-run APP=kolos
make app-diff APP=kolos
make app-apply APP=kolos
```

После rollout:

- [ ] frontend Ready.
- [ ] backend Ready.
- [ ] PostgreSQL healthy.
- [ ] uploads persistent.
- [ ] PVC Bound.
- [ ] Ingress works.
- [ ] `https://agro.godny.tech` works.
- [ ] `https://api.agro.godny.tech` works.

## Phase 7 — Resource validation

После запуска обоих приложений проверить:

- [ ] CPU.
- [ ] RAM/swap.
- [ ] disk usage/IO.
- [ ] Pod requests/limits.
- [ ] Pod restarts.
- [ ] PVC usage.
- [ ] Node conditions.
- [ ] достаточный headroom для стабильной работы.

## Phase 8 — PromBizTech Analytics Platform audit

Найти фактический каталог **PromBizTech Analytics Platform** на ZUER.

Изучить:

- [ ] Prometheus.
- [ ] Grafana.
- [ ] Loki/логирование.
- [ ] exporters.
- [ ] scrape configs.
- [ ] alerts.
- [ ] dashboards.
- [ ] storage/retention.

Сохранить фактическую архитектуру в:

```text
docs/monitoring/platform.md
```

Не создавать параллельный monitoring stack, если существующий можно расширить.

## Phase 9 — Monitoring standardization

Обеспечить visibility для:

### ZUER

- [ ] CPU/load.
- [ ] RAM/swap.
- [ ] filesystem.
- [ ] disk IO.
- [ ] network.
- [ ] temperatures.
- [ ] GPU/VRAM/temperature.
- [ ] Docker/container runtime.

### Kubernetes

- [ ] Node conditions.
- [ ] Pods/restarts.
- [ ] CPU/RAM usage.
- [ ] requests/limits.
- [ ] Deployments/StatefulSets.
- [ ] PV/PVC.
- [ ] ingress metrics.

### Applications

- [ ] Kolos frontend/backend/PostgreSQL.
- [ ] Anaconda frontend/API/PostgreSQL.
- [ ] availability.
- [ ] request rate.
- [ ] latency.
- [ ] HTTP status classes.
- [ ] DB connections/latency/size.

## Phase 10 — Grafana dashboards

Минимальный набор:

- [ ] ZUER Overview.
- [ ] Kubernetes Overview.
- [ ] Applications Overview.
- [ ] Kolos.
- [ ] Anaconda.
- [ ] PostgreSQL.
- [ ] Traefik / Edge.
- [ ] Storage.
- [ ] GPU.

Использовать стандарт `skills/monitoring-observability/SKILL.md`.

## Phase 11 — Alerts

Минимально полезные alerts:

- [ ] node unavailable.
- [ ] application unavailable.
- [ ] database unavailable.
- [ ] filesystem/PVC almost full.
- [ ] excessive pod restarts.
- [ ] ingress unavailable.
- [ ] backup failed.
- [ ] TLS expiry.
- [ ] GPU overheating.

## Phase 12 — Documentation and standardization

После фактического deployment сформировать единый стандарт onboarding следующего приложения на `godny.tech`.

Обновить по факту:

- [ ] `tasks/CURRENT.md`.
- [ ] `docs/state/latest-audit.md`.
- [ ] `docs/monitoring/platform.md`.
- [ ] app README/runbooks.
- [ ] skills при появлении reusable knowledge.
- [ ] README/AGENTS только там, где нужны ссылки или правила верхнего уровня.

## Definition of Done

Все четыре публичные точки отвечают ожидаемо:

```text
https://agro.godny.tech
https://api.agro.godny.tech
https://anaconda.godny.tech
https://api.anaconda.godny.tech
```

Одновременно:

- [ ] Kubernetes node Ready.
- [ ] required Pods Ready.
- [ ] PostgreSQL instances healthy.
- [ ] required PVC Bound.
- [ ] ingress healthy.
- [ ] Docker Traefik routing healthy.
- [ ] TLS healthy.
- [ ] existing services not broken.
- [ ] resource headroom acceptable.
- [ ] metrics collected.
- [ ] core dashboards functional.
- [ ] critical alerts configured.
- [ ] docs/tasks/skills synchronized.
- [ ] Git changes committed and pushed.

## Blockers

- **Anaconda production rollout:** временно ожидает завершения `tasks/SECRETS_HYGIENE.md`. Пользователь решил на тестовом этапе не ротировать Telegram/IMAP credentials, а очистить current tree/history, внедрить Ansible Vault и allowlisted Secret workflow. После `SECRETS HYGIENE: READY` этот blocker снимается.
- Source hardening Anaconda находится в опубликованной ветке `agent/anaconda-k8s-readiness`; history rewrite может изменить SHA, поэтому после secrets cleanup ссылки на старые `fdc178d`/`aeef02d` необходимо актуализировать.

## Decisions

- Kolos остаётся на `agro.godny.tech` / `api.agro.godny.tech`.
- Anaconda использует `anaconda.godny.tech` / `api.anaconda.godny.tech`.
- Docker Traefik остаётся внешним edge proxy.
- ingress-nginx остаётся внутренним Kubernetes ingress.
- существующий repository framework и Makefile используются вместо нового deployment framework.
- проверки адаптируются к риску: быстро для LOW/MEDIUM, подтверждение только для реального HIGH risk.
- production-like secret source of truth: encrypted Ansible Vault; local `.env` допустим только как gitignored/bootstrap source с `chmod 600`.
- Kubernetes Secret создаётся только из allowlisted keys; весь `.env` целиком не импортируется.
- на текущем тестовом этапе credentials сохраняются без ротации по явному решению пользователя; перед реальным production использованием их необходимо перевыпустить.
