# Ход-отчёт: k8s platform scaffold

Дата: 2026-07-10

## Цель

Подготовить репозиторий `sysadmin` к безопасному развёртыванию Kubernetes и
последующей миграции `black_mamba`, `anaconda`, `kolos`, `barber`.

## Что сделано

- Зафиксирована архитектурная модель Kubernetes-платформы.
- Добавлены ADR по k3s, edge Traefik, secrets и local-path storage.
- Добавлен runbook bootstrap-процесса.
- Добавлен `Makefile` для preflight, check, dry-run, diff, apply и backup.
- Добавлены scripts для preflight, k3s install check/apply, ingress-nginx,
  создания Secret из `.env`, сборки образов и PostgreSQL dump.
- Добавлен Kubernetes base: namespaces, quotas, limit ranges, network policies,
  local-path StorageClass, local registry.
- Добавлен шаблон нового приложения `apps/_template`.
- Добавлены стартовые manifests для `barber`, `anaconda`, `kolos`,
  `black-mamba`.

## Изменённые файлы

- `docs/architecture/kubernetes-platform.md`
- `docs/decisions/ADR-0001-k3s-local-platform.md`
- `docs/decisions/ADR-0002-docker-traefik-edge.md`
- `docs/decisions/ADR-0003-secrets-model.md`
- `docs/decisions/ADR-0004-local-path-storage.md`
- `docs/runbooks/k8s-platform-bootstrap.md`
- `docs/runbooks/app-onboarding.md`
- `docs/reports/2026-07-10-k8s-platform-scaffold.md`
- `Makefile`
- `scripts/k8s/*`
- `scripts/backup/postgres-dump.sh`
- `k8s/base/*`
- `k8s/overlays/local/kustomization.yaml`
- `k8s/overlays/prod/kustomization.yaml`
- `apps/_template/*`
- `apps/barber/*`
- `apps/anaconda/*`
- `apps/kolos/*`
- `apps/black-mamba/*`

## Выполненные команды

```bash
git status --short
find . -maxdepth 3 ...
mkdir -p ...
bash -n scripts/k8s/*.sh scripts/backup/postgres-dump.sh
python3 YAML parse check
make k8s-preflight
make k8s-install-check
```

## Проверки

- Shell syntax: успешно.
- YAML parse: успешно.
- `make k8s-install-check`: успешно, изменений хоста нет.
- `make k8s-preflight`: корректно остановился на read-only mounts.
- `kubectl`/`helm`/`kustomize` отсутствуют в текущем `PATH`, поэтому
  `kustomize build`, `kubectl dry-run` и `kubectl diff` не выполнялись.

## Результат

Репозиторий получил стартовый Kubernetes platform scaffold. Runtime хоста и
кластер не изменялись.

## Риски

- Применение кластера на хосте пока не выполнялось.
- GPU runtime для `black_mamba/ollama` требует отдельного preflight.
- `/mnt/ufiles` и `/run/media/nsadmin/godny_soft` в текущей execution-среде
  видны как `ro`; перед реальным deploy нужно проверить это на хосте вне
  sandbox.
- Docker доступ из текущей сессии ограничен; сборку/push образов выполнять от
  пользователя с доступом к Docker или через `sudo`.

## Что осталось

- Установить `kubectl`, `helm`, `kustomize`, `k3s`.
- Прогнать `kubectl apply --dry-run=server` и `kubectl diff`.
- Добавить реальные `.env`/Secrets локально.
- Собрать и отправить app images в local registry.
- Перед `kolos` и `black_mamba` выполнить backup/restore drill.

## Rollback

Удалить добавленные файлы `docs/architecture`, `docs/decisions`,
`docs/runbooks`, `docs/reports/2026-07-10-k8s-platform-scaffold.md`,
`Makefile`, `scripts/k8s`, `scripts/backup/postgres-dump.sh`, `k8s`, `apps`.
Runtime хоста не изменён.
