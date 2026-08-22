# Anaconda Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для `kip-service/anaconda_mvp`:

- FastAPI API;
- Vue/Vite frontend;
- PostgreSQL 16.

## Перед deploy

```bash
make k8s-preflight
make anaconda-secret-dry-run
make app-build APP=anaconda IMAGE_TAG=git-aeef02d
make app-push APP=anaconda IMAGE_TAG=git-aeef02d
make app-dry-run APP=anaconda
make app-diff APP=anaconda
make anaconda-secret-apply
```

`anaconda-secret-apply` читает encrypted Ansible Vault и передаёт только
`POSTGRES_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `EMAIL_IMAP_USER` и
`EMAIL_IMAP_PASSWORD`. Generated plaintext YAML не создаётся.

После apply:

```bash
./apps/anaconda/scripts/smoke.sh
```

## Важно

PostgreSQL не публикуется наружу. Telegram webhook должен указывать на внешний
HTTPS URL после переключения ingress.

Git history очищена. Для текущего тестового rollout пользователь сохранил
существующие Telegram/IMAP credentials и принял residual risk. Перед реальным
production использованием их необходимо перевыпустить.

Frontend image собирается как статический Vite build и работает под
unprivileged Nginx на `8080`. После history rewrite source branch tip:
`41f5a8f` (`agent/anaconda-k8s-readiness`). Существующие immutable image tags
`git-aeef02d` сохранены как исторические registry identifiers и по-прежнему
проверяются по OCI digest.

Backup/restore procedure: [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).
