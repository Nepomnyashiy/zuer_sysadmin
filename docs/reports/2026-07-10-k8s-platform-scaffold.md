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
- На хосте установлен `k3s v1.36.2+k3s1`.
- Установлен `ingress-nginx` через Helm с NodePort `30080/30443`.
- Применён platform base: namespaces, quotas, limit ranges, network policies,
  `osnova-local-retain` StorageClass и local registry на NodePort `30500`.

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
sudo make k8s-install
make k8s-install-ingress
kubectl apply -f k8s/base/namespaces/namespaces.yaml
kubectl apply -f k8s/base/policies/limitranges.yaml ...
```

## Проверки

- Shell syntax: успешно.
- YAML parse: успешно.
- `make k8s-install-check`: успешно, изменений хоста нет.
- `make k8s-preflight`: корректно остановился на read-only mounts.
- `kubectl get nodes -o wide`: node `zuer` Ready.
- `kubectl get pods -A`: system pods Running.
- `ingress-nginx`: controller Running, service `80:30080`, `443:30443`.
- Local registry: pod Running, PVC Bound, `curl http://127.0.0.1:30500/v2/`
  возвращает `200`.
- `kubectl apply --dry-run=server` для base manifests: успешно.
- `kubectl diff` для base manifests: без diff.

## Результат

Репозиторий получил стартовый Kubernetes platform scaffold. Runtime хоста
подготовлен: k3s, ingress-nginx и platform base установлены.

## Риски

- GPU runtime для `black_mamba/ollama` требует отдельного preflight.
- k3s default `local-path` StorageClass имеет `reclaimPolicy: Delete`; для
  наших PVC используется отдельный `osnova-local-retain`.
- k3s/flannel не enforcing NetworkPolicy, policies пока фиксируют intent.

## Что осталось

- Добавить реальные `.env`/Secrets локально.
- Собрать и отправить app images в local registry.
- Перенести первое приложение `barber`.
- Перед `kolos` и `black_mamba` выполнить backup/restore drill.

## Rollback

Удалить добавленные файлы `docs/architecture`, `docs/decisions`,
`docs/runbooks`, `docs/reports/2026-07-10-k8s-platform-scaffold.md`,
`Makefile`, `scripts/k8s`, `scripts/backup/postgres-dump.sh`, `k8s`, `apps`.
Runtime хоста не изменён.
