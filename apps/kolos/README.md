# Kolos Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для `kolos_web`:

- Strapi backend;
- Next.js frontend;
- PostgreSQL 16;
- PVC для Strapi uploads.

## Перед deploy

```bash
make k8s-preflight
./scripts/k8s/create-secret-from-env.sh kolos kolos-secret /run/media/nsadmin/godny_soft/soft/kolos_web/.env
make app-build APP=kolos
make app-push APP=kolos
make app-dry-run APP=kolos
make app-diff APP=kolos
```

## Важно

Перед переключением `agro.godny.tech` и `api.agro.godny.tech` нужен backup:

- dump PostgreSQL;
- архив `kolos-backend/public/uploads`;
- проверка restore на временной базе.

