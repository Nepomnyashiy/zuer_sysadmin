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

## Source commits

- `fdc178d fix: harden Anaconda production images`.
- `aeef02d fix: build database URL from Kubernetes env`.

Оба commits опубликованы в `agent/anaconda-k8s-readiness` репозитория
`Nepomnyashiy/anaconda-mvp`.

## Images

- `127.0.0.1:30500/anaconda/api:git-aeef02d` ->
  `sha256:0c77ea569879ff15003c7f8f71d025ca75eb98128992217fd41d07d0c752cd6b`.
- `127.0.0.1:30500/anaconda/web:git-aeef02d` ->
  `sha256:3f02d8b77ff1b7b548ac1a87bb5687485e5c9c49d64d97b4116baff9515c3d54`.

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

## Blocker

До production Secret/apply требуется ротация Telegram bot token и IMAP app
password. Удаление значений из текущего HEAD не удаляет их из Git history.

## Следующий шаг

1. Пользователь ротирует Telegram/IMAP credentials вне Git.
2. Обновляет локальный `.env` новыми значениями.
3. Агент создаёт Secret через allowlist, повторяет dry-run/diff, выполняет apply,
   rollout и `apps/anaconda/scripts/smoke.sh`.
4. Только после smoke test добавляется live Traefik route по одному host.

## Rollback

- Runtime Anaconda не применялся; удалять namespace/PVC не требуется.
- Registry содержит только новые immutable tags; существующие tags не
  перезаписаны.
- Source changes откатываются revert commits `aeef02d` и `fdc178d`.
- Platform changes откатываются revert соответствующего sysadmin commit.
