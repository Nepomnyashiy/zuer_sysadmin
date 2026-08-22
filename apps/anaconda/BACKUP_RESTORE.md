# Anaconda PostgreSQL backup and restore

## Scope

- Namespace: `anaconda`.
- StatefulSet/label: `anaconda-postgres`.
- Database/user: `anaconda_db` / `anaconda_user`.
- PVC: `data-anaconda-postgres-0`.
- StorageClass: `osnova-local-retain` (`Retain`).
- Backup root: `/mnt/ufiles/k8s-backups/postgres`.

На аудите 2026-08-21 existing Anaconda Docker containers/volumes не найдены,
поэтому первый Kubernetes rollout создаёт новую пустую PostgreSQL. Если до
rollout появится другой источник данных, deployment нужно остановить и сначала
согласовать migration/restore plan.

## Backup

Перед schema/app upgrade и не реже одного раза в сутки:

```bash
make backup-postgres \
  NS=anaconda \
  APP=anaconda-postgres \
  DB=anaconda_db \
  USER=anaconda_user
```

Скрипт создаёт custom-format dump (`pg_dump -Fc`) с mode `0600` в:

```text
/mnt/ufiles/k8s-backups/postgres/anaconda/anaconda-postgres/
```

Проверка dump без восстановления через PostgreSQL Pod (host `pg_restore` на
ZUER не установлен):

```bash
kubectl -n anaconda exec -i anaconda-postgres-0 -- \
  pg_restore --list < /path/to/anaconda_db-YYYYMMDD-HHMMSS.dump >/dev/null
```

Backup считается готовым только после успешного `pg_restore --list` и
периодического restore drill в отдельную тестовую БД.

## Restore

Restore с `--clean` изменяет/удаляет объекты БД и относится к HIGH risk.
Перед выполнением нужны подтверждение пользователя, свежий pre-restore dump и
зафиксированный exact dump path.

План:

1. Проверить dump через containerized `pg_restore --list`, как показано выше.
2. Создать свежий backup текущей БД.
3. Остановить writers (`anaconda-api` replicas `0`).
4. Передать dump в Pod и выполнить `pg_restore --clean --if-exists`.
5. Вернуть API replicas `1`, дождаться rollout и выполнить smoke test.
6. При ошибке восстановить pre-restore dump тем же процессом.

Пример команды restore после отдельного подтверждения:

```bash
kubectl -n anaconda exec -i anaconda-postgres-0 -- \
  pg_restore \
  --username=anaconda_user \
  --dbname=anaconda_db \
  --clean \
  --if-exists \
  --no-owner < /exact/path/to/anaconda_db.dump
```

## RPO / RTO

- Начальный RPO: 24 часа и обязательный backup перед изменениями.
- Начальный RTO: 60 минут.

Это стартовые цели для single-node платформы, а не гарантия HA. После первого
restore drill зафиксировать фактические duration и размер dump.

## PVC safety

PVC/PV не удалять для rollback. `Retain` защищает PV после удаления claim, но
не заменяет dump и не защищает от логической порчи данных.
