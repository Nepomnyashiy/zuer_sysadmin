# Barber Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для сервиса барбершопа:

- Next.js frontend;
- FastAPI backend;
- PostgreSQL 15;
- Redis 7.

## Перед deploy

```bash
make k8s-preflight
./scripts/k8s/create-secret-from-env.sh barber barber-secret /run/media/nsadmin/godny_soft/soft/barber/.env
make app-build APP=barber
make app-push APP=barber
make app-dry-run APP=barber
make app-diff APP=barber
```

## Важно

Текущий frontend Dockerfile запускает `npm run dev`. Для production нужно
перевести его на `next build` и `next start`, иначе Kubernetes будет запускать
dev-сервер.

Backend пока не имеет `/health`; readiness/liveness временно используют `/`.

