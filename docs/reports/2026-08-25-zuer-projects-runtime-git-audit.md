# Полный аудит проектов, runtime и Git-состояния ZUER

Дата: 2026-08-25

## Резюме

ZUER работоспособен. Docker Traefik остаётся единственной edge-точкой на
`80/443`; k3s обслуживает PromBiz.Tech, Anaconda Site и платформенные
компоненты; Nextcloud, AI/LLM и PromBiz staging продолжают работать в Docker
Compose. Узел Kubernetes Ready, все активные Pods Ready, systemd failed units
отсутствуют, последний ежедневный backup завершён успешно.

Инфраструктура находится в переходном, а не полностью стандартизированном
состоянии. Часть live-конфигурации декларативна и совпадает с Git, часть
остаётся в host paths и Docker Compose, а часть подготовленных Git-манифестов
ещё не является production-ready. Monitoring stack Prometheus/Grafana/Loki
не развёрнут.

Объединение возможно, но должно выполняться по репозиториям и тематическим
коммитам. Нельзя объединять все каталоги сервера в одну Git-ветку: это разные
репозитории, жизненные циклы и границы ответственности.

## 1. Состояние хоста

| Параметр | Фактическое состояние |
| --- | --- |
| Host | `ZUER`, Ubuntu 26.04 LTS, kernel `7.0.0-29-generic` |
| Uptime | 6 дней 3 часа |
| CPU | Intel Core i5-12600KF, 10 cores / 16 threads; load около 0.8 |
| RAM | 30 GiB total, 13 GiB used, 16 GiB available |
| Swap | 8 GiB total, 2.4 GiB used |
| GPU | RTX 4060 8 GiB; около 1.3 GiB VRAM, 4-10%, 43 C |
| Root FS | 109 GiB, 72% used, около 30 GiB free |
| `/mnt/ufiles` | 916 GiB, 32% used, rw |
| `godny_soft` | 220 GiB, 7% used, rw |
| `x-files` | 1.9 TiB, 59% used, rw |
| `mega-files` | 1.9 TiB, 55% used, rw |
| systemd failures | 0 |
| k3s | enabled, active, no service restarts in current boot |
| Docker | 29.1.3 |

Capacity сейчас достаточен, но рост swap с почти нулевого значения до 2.4 GiB
нужно наблюдать. Root filesystem и Docker image storage требуют планового
контроля, а не немедленного destructive prune.

## 2. Backup

- `osnova-backup.timer` активен.
- Последний daily backup: 2026-08-25 03:32-03:33 MSK.
- Result: `success`, exit status `0`.
- Создано 7 daily Restic snapshots; retention применён успешно.
- Metadata check и prune завершались успешно.
- Full-data check timer ещё не имеет фактического completed run в показанном
  systemd state; первый подтверждённый результат следует проверить отдельно.
- Repository расположен на `/mnt/ufiles/restic/zuer`: это хороший локальный
  recovery layer, но не off-site disaster recovery.

## 3. Runtime-карта

### 3.1 Kubernetes / k3s

| Namespace / сервис | Runtime | Состояние | Публикация | Подход |
| --- | --- | --- | --- | --- |
| `prombiz/prombiz-site` | Deployment, static Astro + Nginx | 1/1 Ready, 0 restarts | `prombiz.tech` через Ingress | immutable digest, non-root, read-only FS, probes/resources |
| `anaconda/anaconda-site` | Deployment, static React/Vite + Nginx | 1/1 Ready, 0 restarts | `anaconda.godny.tech` | immutable tag+digest, ClusterIP, Ingress |
| Anaconda legacy API/web | Deployments | replicas 0 | не обслуживают трафик | retained rollback resources |
| Anaconda PostgreSQL | StatefulSet/PVC | replicas 0, PVC Bound 20 GiB | internal only | retained data, `Retain` |
| ingress-nginx | Deployment + NodePort | 1/1 Ready | `30080/30443` | внутренний ingress layer |
| local registry | Deployment + PVC + NodePort | 1/1 Ready | localhost/LAN `30500` | local registry, PVC Retain |
| CoreDNS | Deployment | 1/1 Ready | internal | k3s system component |
| metrics-server | Deployment | 1/1 Ready | internal | resource metrics only |
| local-path-provisioner | Deployment | 1/1 Ready | internal | local single-node storage |

Node `zuer` Ready; MemoryPressure, DiskPressure и PIDPressure отсутствуют.
Requests: 475m CPU / 620 MiB RAM. Limits: 2250m CPU / 1834 MiB RAM.
Фактическое node usage около 4% CPU и 42% RAM.

Git/live diff:

- `apps/anaconda/k8s`: clean.
- `apps/prombiz/k8s`: clean.
- `k8s/overlays/local`: drift по label namespace `anaconda`; platform base
  хочет удалить `app.kubernetes.io/name=anaconda`, а app manifest его
  устанавливает. Это конфликт двух владельцев Namespace.

### 3.2 Docker Compose

| Compose project | Компоненты | Состояние | Данные | Публикация |
| --- | --- | --- | --- | --- |
| `traefik` | Traefik v3.1.7 | running | ACME bind mount | host 80/443 |
| `nextcloud` | Nextcloud 34, MariaDB 11, Redis 7 | 3 running | volumes + `/mnt/ufiles` + external storage | `cloud.godny.tech` |
| `local_llm` | Ollama, 2 Open WebUI, LiteLLM, pgvector, pgAdmin, BM API | 7 running, Hermes created | Docker volumes + `/mnt/ufiles/ollama/models` | `ai.godny.tech`, `llm.godny.tech`; admin/local ports only |
| `prombiztech-staging` | legacy PromBiz web | running healthy | stateless | `prombiz.godny.tech` |
| `prombiztech-production` | old production web | FROZEN, exited, restart=no | stateless | route отключён |
| `prombiztech-dev` | web/api/PostgreSQL/Redis | exited | retained dev volumes | localhost only |

Активны 12 Docker containers. Всего сохранено 23 containers; 11 остановлены
или находятся в `created`, включая пять anonymous build/test leftovers.
Удаление этих объектов не выполнялось.

### 3.3 Самостоятельные host services

- Docker, containerd и k3s работают как systemd services.
- SSH работает на 22/tcp.
- XRDP слушает 3389/tcp; фактическую UFW policy без интерактивного sudo
  подтвердить не удалось.
- Hiddify работает как пользовательское приложение на localhost proxy ports.
- Backup управляется systemd timers/services.
- User crontab `nsadmin` отсутствует.
- Prometheus, Grafana, Loki, Alloy, Alertmanager, exporters не работают ни в
  Docker, ни в Kubernetes.

## 4. Edge и публичные сервисы

Текущая цепочка для Kubernetes приложений:

```text
Internet -> router/NAT -> Docker Traefik :80/:443
-> 192.168.0.101:30080 -> ingress-nginx
-> Kubernetes Ingress -> ClusterIP -> Pod
```

| Host | HTTP result | Backend | Статус |
| --- | ---: | --- | --- |
| `cloud.godny.tech` | 302 `/login` | Docker Nextcloud | active |
| `traefik.godny.tech` | 401 | Traefik dashboard | active, Basic Auth |
| `ai.godny.tech` | 200 | Docker Open WebUI AI | active |
| `llm.godny.tech` | 200 | Docker LiteLLM | active |
| `prombiz.godny.tech` | 200 | Docker PromBiz staging | active |
| `prombiz.tech` | 200 | Kubernetes PromBiz.Tech | active production |
| `www.prombiz.tech` | 301 | canonical redirect | active |
| `anaconda.godny.tech` | 200 | Kubernetes Anaconda Site | active |
| `api.anaconda.godny.tech` | 404 | stale Traefik router to ingress | obsolete |
| `agro.godny.tech` | 404 | no router/workload | DNS exists, not deployed |
| `api.agro.godny.tech` | 404 | no router/workload | DNS exists, not deployed |

Edge risks:

1. `ai.godny.tech` объявлен дважды: в `routes.yml` и
   `openwebui-ai.yml`. Сейчас запрос фактически выбирает
   `openwebui-ai@file`, но ownership hostname неоднозначен.
2. Live `k8s-anaconda.yml` всё ещё содержит router
   `api.anaconda.godny.tech`, хотя desired template публикует только web host.
3. Traefik dynamic directory смонтирован read-only в основном container;
   изменения должны приходить через Ansible или контролируемый helper.
4. Публичный edge постоянно получает автоматические vulnerability scans.
   Наблюдались 404 на типовых exploit paths; признаков успешного исполнения
   по этим логам нет.
5. ingress-nginx ConfigMap не задаёт явные forwarded-header/real-IP policies.

## 5. Состояние проектов и исходного кода

| Проект | Git/runtime | Состояние source | Вывод |
| --- | --- | --- | --- |
| `anaconda_web` | Git clean; production в k3s | `agent/prombiz-rebrand` synced | эталон для нового stateless сайта |
| `anaconda_site` | production в k3s | основной `master` dirty и behind 2; live build из `/tmp` worktree commit `22a7f3f`; есть второй `/tmp` worktree `ed43e7b` | воспроизводимость зависит от временных worktree; нужен durable canonical checkout |
| `anaconda_mvp` | retained k3s resources replicas 0 | branch clean/synced | legacy, не удалять до решения по data/PVC |
| `black_mamba` | active Docker Compose | root `main` clean, но без upstream; nested Hermes repo dirty | работает, но использует mutable `main/latest` images и mixed working-dir labels |
| `barber` | runtime отсутствует | 236 KiB source без Git, содержит `.env` | нельзя считать production source-of-truth; manifests только scaffold |
| `kolos_web` | runtime отсутствует, public 404 | main с большим dirty tree; 4.9 GiB checkout | migration blocked data/backup/review |
| `gigavpn` | Docker/systemd runtime не найден в этом аудите | main dirty, включая потенциально чувствительные JSON/env files | не объединять без отдельного security review |
| `prombiztech` | staging Docker; old production frozen | `integration/2.2.2`, untracked docs, tracking настроен на `origin/main`, ahead 66 | branch/upstream contract требует исправления |
| `prombiztech-analytics-platform` | runtime отсутствует | worktree того же repo; branch ahead 7/behind 14 и dirty | observability implementation существует в коде, но не deployed |
| `sysadmin` | source of truth инфраструктуры | canonical `agent/sysadmin`, dirty tree смешанного происхождения | требует тематической нормализации |
| `go`, `bin` | operational/local tools | отдельного runtime не выявлено | не путать с приложениями |

PromBizTech worktrees являются двумя рабочими деревьями одного Git repository.
`integration/2.2.2` и `agent/v2-2-2-analytics-platform` расходятся на 14 и 7
коммитов. Analytics branch добавляет 42 files / около 2366 lines: ingestion
API, schema, Prometheus, Grafana, Loki, Alloy, dashboards и runbooks.
Read-only `merge-tree` не показал Git conflict markers, но оба worktree имеют
незакоммиченные изменения, поэтому merge сейчас небезопасен.

## 6. Что находится в dirty tree sysadmin

| Файл/каталог | Содержание | Класс | Рекомендация | Возможное влияние |
| --- | --- | --- | --- | --- |
| `ansible/group_vars/all.yml` | host/ports OpenWebUI + Hermes | meaningful IaC | отдельный `feat(ai)` commit после сверки live | при apply меняет generated registry/templates, не runtime сам по себе |
| `ansible/templates/registry-domains.md.j2` | AI host переведён planned/private -> active/public | meaningful docs template | объединить с AI vars | изменит `/srv/registry/domains.md` после playbook |
| `ansible/web/godny.tech.zone.txt` deleted | старый Spaceweb zone snapshot 2025 с устаревшими данными | obsolete reference | заменить актуальным DNS runbook/sanitized snapshot, затем удалить | live DNS не меняется; теряется старый reference |
| `.npmrc` | user-specific npm prefix | local config | не коммитить; добавить в ignore | runtime не влияет |
| `package.json`, lock, `node_modules` | локальная установка Gemini CLI; 157 MiB | workstation tooling | вынести из infra repo, ignore `node_modules`; CLI ставить user-level | коммит резко раздует repo и создаст ложный Node dependency |
| `QWEN.md` | альтернативные agent instructions для локального Ollama | local/tool policy | согласовать с `AGENTS.md`/`CODEX.md`, не делать параллельным source of truth | противоречивые правила для агентов |
| `ansible/nextcloud-pushkin.yml` | per-minute Nextcloud targeted scan cron | meaningful but unverified | сохранить только вместе с актуальным report и live verification | при apply создаёт ежеминутный IO/DB scan |
| `2026-07-27-nextcloud-pushkin-access.md` | описание пользователя/share/cron | historical report with drift | обновить: user crontab сейчас отсутствует | иначе документация утверждает несуществующий cron |
| traffic-flow current/target | качественный audit/architecture от 2026-07-14 | historical + architecture | commit после маркировки AS-OF и ссылки на новый audit | current document сейчас устарел: k3s apps уже live |
| `2026-07-14-zuer-traffic-audit.md` | исторический traffic audit | historical evidence | можно commit как historical | не считать current state |
| `2026-07-17-k8s-platform-full-audit.md` | исторический k3s audit | historical evidence | можно commit как historical | registry/app state уже изменились |
| `scripts/hostinfo/*`, archive | CPU/disk/network/users/packages snapshots | generated/sensitive metadata | не коммитить; ignore или хранить вне repo | раскрывает topology/user/package inventory, быстро устаревает |

Неизвестные dirty-файлы не содержат подтверждённых runtime secret values по
выполненному pattern scan, но полноценный gitleaks отсутствует. Особенно
`gigavpn` JSON/env/key candidates требуют отдельного сканирования без вывода
значений.

## 7. Качество инфраструктурного кода

Положительное:

- Все 10 Ansible playbooks проходят `--syntax-check`.
- Все 7 Kustomize targets собираются.
- Все 17 shell scripts проходят `bash -n`.
- Anaconda и PromBiz desired state совпадают с live.
- Используются Namespace, ClusterIP, Ingress, probes, resources, security
  contexts, immutable digests и Retain storage.
- Backup automation и restore documentation присутствуют.
- Secrets отделены через encrypted Ansible Vault/local env/Kubernetes Secret.

Проблемы:

- Нет `.github/workflows`, GitOps controller или CI gate для Kustomize,
  Ansible и shell checks.
- `ansible-lint`, `yamllint`, `kubeconform`, `shellcheck` на host не найдены.
- Platform Namespace и app Namespace имеют двойной ownership.
- `preflight.sh` предупреждает, что NodePort не слушает в `ss`, хотя сам skill
  правильно указывает, что NodePort надо проверять функционально.
- Часть live compose metadata ссылается на старый путь
  `/run/media/nsadmin/godny_soft1/...`; текущий source находится на
  `godny_soft`. Recreate может вести себя иначе, чем текущие containers.
- Compose deploy некоторых сервисов нельзя воспроизвести без root-only env
  files; это ожидаемо, но runbook должен явно описывать команды.
- Несколько critical services не имеют Docker healthcheck.
- AI images используют mutable tags: Open WebUI `main`, LiteLLM
  `main-latest`, Ollama `latest`, BM API `latest`.
- Docker содержит 36.37 GiB images, 25.24 GiB reclaimable, и 6.5 GiB build
  cache. Cleanup plan нужен, но prune без inventory/rollback запрещён.
- Single-node k3s не обеспечивает HA.
- Flannel NetworkPolicy не следует считать enforcement boundary.

## 8. Monitoring / observability

Сейчас доступны только:

- health endpoints;
- Kubernetes probes/events;
- stdout/stderr logs;
- metrics-server и `kubectl top`;
- Traefik access logs;
- systemd/journal;
- backup unit status.

Namespace `monitoring` содержит только default root CA ConfigMap.
Prometheus, Grafana, Loki, Alloy и Alertmanager отсутствуют.

В `agent/v2-2-2-analytics-platform` уже есть implementation observability
Compose, dashboards, alert rules и tests, но это код будущего контура, а не
фактическая monitoring platform ZUER. Его нельзя описывать как работающий
сервис до merge, deploy и smoke.

## 9. Можно ли объединить ветки

### sysadmin

Да. `main` и `k8s-platform-scaffold` являются предками `agent/sysadmin`.
Технически main можно fast-forward до `agent/sysadmin` без code conflict.
Remote default branch всё ещё указывает на `k8s-platform-scaffold`, поэтому
простого локального merge недостаточно.

Безопасный порядок:

1. Классифицировать dirty tree и создать тематические commits.
2. Не включать generated/local artifacts.
3. Создать backup tag `pre-main-unification-2026-08-25`.
4. Проверить Kustomize/Ansible/shell syntax и Git/live diff.
5. Fast-forward `main` до проверенного `agent/sysadmin`.
6. Push `main`, изменить GitHub default branch на `main`.
7. Обновить clones, docs и automation references.
8. Старые branches сначала оставить как rollback references; удалять позже.

Влияние: само Git-объединение runtime не меняет. Runtime изменится только при
запуске Ansible, `kubectl apply`, Docker Compose или edge playbook. Риск
заключается в том, что future operators начнут считать новый main source of
truth, поэтому в него нельзя переносить stale/generated/secret-prone files.

### PromBizTech application repository

Объединение тоже возможно, но не fast-forward. Сначала нужно:

1. Зафиксировать или убрать dirty changes в обоих worktree.
2. Исправить upstream tracking branches.
3. Merge 14 новых integration commits в analytics branch.
4. Прогнать web/API/data/observability tests.
5. Проверить staging Compose и выполнить staging rollout.
6. Только затем сформировать единую release branch.

Влияние на production отсутствует до build/deploy. Влияние на staging
возникнет после нового image rollout: analytics migrations, ingestion API,
PostgreSQL schema, Grafana/Prometheus/Loki/Alloy и новые volumes увеличат
ресурсное потребление и backup scope.

### Разные repositories

`sysadmin`, `anaconda_web`, `anaconda_site`, `kolos_web`, `black_mamba`,
`gigavpn` и PromBizTech не следует физически объединять в одну branch.
Рекомендуемая модель: отдельные app repositories + один infrastructure
repository, который pin-ит release image digests.

## 10. Целевой стандарт

Для каждого сервиса:

```text
clean canonical main
-> tested immutable image git-<sha>@sha256
-> local registry
-> namespace
-> Deployment/StatefulSet
-> ClusterIP
-> Ingress
-> ingress-nginx
-> Docker Traefik
-> public HTTPS
```

Обязательные контракты:

- один владелец каждого hostname;
- durable source path, никаких production dependencies на `/tmp` worktree;
- non-root runtime, probes, requests/limits;
- mutable tags запрещены для production;
- database/Redis/admin ports internal only;
- stateful data: PVC Retain + backup + restore drill + RPO/RTO;
- secrets: Vault/SOPS/allowlisted Kubernetes Secret, не Git/build args;
- edge change: internal Host smoke -> backup -> cutover -> public smoke;
- logs/metrics/dashboards/alerts до статуса production-ready;
- current state docs отделены от historical reports;
- CI checks для Kustomize, Ansible, shell и secret scan.

## 11. Приоритетный план стандартизации

### P0 — безопасность и source of truth

1. Нормализовать dirty tree sysadmin тематическими commits.
2. Добавить ignore для `node_modules`, `.npmrc` и generated hostinfo.
3. Устранить два router для `ai.godny.tech`.
4. Удалить stale Anaconda API router через проверенный edge workflow.
5. Убрать production dependency Anaconda от `/tmp` worktree.
6. Проверить UFW с интерактивным sudo и зафиксировать effective rules.

### P1 — воспроизводимость

1. Fast-forward sysadmin `main` и изменить default branch.
2. Исправить Namespace ownership drift.
3. Pin AI/Nextcloud/Traefik/registry images по version/digest.
4. Добавить healthchecks всем критичным Docker services.
5. Исправить stale Compose working-dir metadata через контролируемый recreate.
6. Создать Git repository для Barber или удалить его из migration queue.

### P2 — приложения

1. Завершить merge/test PromBizTech analytics branch.
2. Аудировать Kolos DB/uploads и dirty source перед deployment.
3. Отдельно проверить GigaVPN secrets/runtime.
4. Black Mamba переносить в k3s только после GPU device-plugin preflight,
   data migration и pinned images.

### P3 — observability и DR

1. Развернуть единый Prometheus/Grafana/Loki/Alloy stack, не второй parallel.
2. Добавить blackbox checks, TLS expiry, Pod restart, disk/PVC и backup alerts.
3. Подключить off-site Restic repository.
4. Выполнить регулярные restore drills для Nextcloud, PostgreSQL и k3s data.

## 12. Действия, не выполненные в рамках аудита

- Dirty user files не изменялись, не удалялись и не индексировались.
- Branch merge/fast-forward не выполнялся.
- Runtime не перезапускался.
- Docker containers/images/volumes не удалялись.
- Kubernetes resources/PVC/PV не изменялись.
- Firewall, SSH и routing не изменялись.
- Secrets и environment values не выводились.

## Итоговый статус

`STATUS: DEGRADED (управляемый)`.

Production PromBiz.Tech, Anaconda, Nextcloud и AI endpoints доступны; k3s и
backup healthy. Статус не `OK` из-за неоднозначного AI route ownership, stale
Anaconda API route, отсутствующего full observability, dirty/divergent source
trees, mutable AI images, `/tmp` production worktrees и неполной декларативности
Compose/live edge.
