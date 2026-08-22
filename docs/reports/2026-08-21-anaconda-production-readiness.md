# Ход-отчёт: Anaconda production readiness

Дата: 2026-08-21

## Цель

Подготовить воспроизводимые production images и Kubernetes manifests Anaconda
до безопасной точки перед Secret/apply.

## Что сделано

- Проаудированы source, Docker Compose, `.env` key names и Kubernetes manifests.
- Создана и опубликована source-ветка `agent/anaconda-k8s-readiness`.
- Frontend переведён с Vite dev server на multi-stage static build и
  unprivileged Nginx `8080`.
- API переведён на non-root user, pinned dependencies, `/live` и DB-aware
  `/ready`; token prefix больше не логируется.
- Current-tree credential literals заменены placeholders/Vault references.
- Добавлены lockfile, `.dockerignore`, pinned base image digests.
- Исправлен frontend API URL для public HTTPS.
- Kubernetes Secret mapping ограничен четырьмя keys.
- Добавлены startup probes, security contexts, immutable app image digests и
  pinned PostgreSQL digest.
- Build и push разделены: push больше не пересобирает image.
- Добавлены backup/restore runbook и smoke test.

## Source commits after history rewrite

- `88fbe3d fix: harden Anaconda production images`.
- `cf7a08a fix: build database URL from Kubernetes env`.
- `41f5a8f fix(secrets): remove plaintext configuration artifacts`.

Commits опубликованы в `agent/anaconda-k8s-readiness` репозитория
`Nepomnyashiy/anaconda-mvp`. Старые SHA стали недействительными после cleanup.

## Images

- `127.0.0.1:30500/anaconda/api:git-aeef02d` ->
  `sha256:0c77ea569879ff15003c7f8f71d025ca75eb98128992217fd41d07d0c752cd6b`.
- `127.0.0.1:30500/anaconda/web:git-aeef02d` ->
  `sha256:3f02d8b77ff1b7b548ac1a87bb5687485e5c9c49d64d97b4116baff9515c3d54`.

Image tag `git-aeef02d` сохранён как исторический immutable registry identifier;
его OCI digest не изменялся и не является ссылкой на доступный после rewrite
Git commit.

## Проверки

- Python и Bash syntax: OK.
- npm production build: OK.
- npm audit: 0 vulnerabilities.
- API/web Docker builds: OK.
- Image users: API `10001`, web `101`.
- Web container smoke: `/healthz` 200, `/` 200, production API URL встроен.
- Kustomize render: OK.
- Server-side dry-run: OK.
- kubectl diff: ожидаемое создание app resources; live workload/PVC не удаляется.
- Registry tags и OCI digests: verified.

## Stateful data

Existing Anaconda containers и Docker volumes не найдены. Новый StatefulSet
создаст пустую PostgreSQL на PVC `data-anaconda-postgres-0` в
`osnova-local-retain`. Если появится другой источник данных, rollout нужно
остановить и сначала подготовить migration/restore.

## Найденные проблемы

- Credential literals присутствовали в tracked source и Git history.
- Старый frontend использовал Vite dev server и public HTTP `:8000`.
- Старый `/health` возвращал HTTP 200 при DB failure.
- Старый Secret workflow импортировал весь `.env`.
- Docker Hub pulls периодически зависают; все выбранные base digests проверены
  перед фиксацией.

## Secrets hygiene gate

Завершён 2026-08-22: current tree и relevant remote history очищены,
encrypted Ansible Vault создан, allowlisted Kubernetes Secret workflow прошёл
client dry-run. Пользователь решил сохранить текущие тестовые credentials без
ротации; перед реальным production использованием они должны быть перевыпущены.

## Следующий шаг

1. Основной deployment-agent синхронизирует `agent/sysadmin`.
2. Повторяет `make anaconda-secret-dry-run`, app dry-run и diff.
3. Выполняет `make anaconda-secret-apply`, app apply, rollout и smoke.
4. Только после smoke test добавляет live Traefik route по одному host.

## Rollback

- Runtime Anaconda не применялся; удалять namespace/PVC не требуется.
- Registry содержит только новые immutable tags; существующие tags не
  перезаписаны.
- Pre-rewrite refs восстанавливаются из защищённого Git bundle, указанного в
  secrets hygiene report; обычные post-rewrite source changes откатываются
  revert commit `41f5a8f`.
- Platform changes откатываются revert соответствующего sysadmin commit.
