# Anaconda Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для `kip-service/anaconda_mvp`:

- FastAPI API;
- Vue/Vite frontend;
- PostgreSQL 16.

## Перед deploy

```bash
make k8s-preflight
./scripts/k8s/create-secret-from-env.sh anaconda anaconda-secret /run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp/.env
make app-build APP=anaconda
make app-push APP=anaconda
make app-dry-run APP=anaconda
make app-diff APP=anaconda
```

## Важно

PostgreSQL не публикуется наружу. Telegram webhook должен указывать на внешний
HTTPS URL после переключения ingress.

