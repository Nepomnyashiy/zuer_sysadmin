# Anaconda Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для `kip-service/anaconda_mvp`:

- FastAPI API;
- Vue/Vite frontend;
- PostgreSQL 16.

## Перед deploy

```bash
make k8s-preflight
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
```

После apply:

```bash
./apps/anaconda/scripts/smoke.sh
```

## Важно

PostgreSQL не публикуется наружу. Telegram webhook должен указывать на внешний
HTTPS URL после переключения ingress.

До production rollout необходимо ротировать Telegram/IMAP credentials, которые
ранее присутствовали в Git history source-репозитория. Secret должен содержать
только четыре keys из allowlist выше; значения в логи и Git не выводятся.

Frontend image собирается как статический Vite build и работает под
unprivileged Nginx на `8080`. API source revision для этого rollout:
`aeef02d` из ветки `agent/anaconda-k8s-readiness`.

Backup/restore procedure: [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).
