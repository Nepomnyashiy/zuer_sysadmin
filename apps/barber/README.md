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

Frontend Dockerfile переведен на production-сборку: `npm run build` во время
build stage и `npm run start` на runtime.

Backend имеет `/health`, который проверяет подключение к PostgreSQL через
`SELECT 1`. Readiness/liveness probes используют этот endpoint.
