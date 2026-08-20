# Эксплуатация резервных копий ZUER

Дата актуализации: 2026-08-20

Статус: production, timers включены
Инструмент: Restic 0.18.1

## 1. Назначение и подтверждённое состояние

Runbook описывает действующую систему backup: состав данных, расписание,
ротацию, ежедневные проверки, ручной запуск, восстановление и аварийные
сценарии.

Backup считается исправным только после создания snapshot, проверки repository
и реального восстановления. Для golden snapshot `c2ad12e1` это подтверждено
2026-08-20:

- snapshot создан за 5 минут 8 секунд;
- логический размер 18.1 GiB;
- metadata check завершился без ошибок;
- full check прочитал 832 packs без ошибок;
- smoke test восстановил и сравнил `/etc/hostname`;
- после snapshot на `/mnt/ufiles` доступно 636 GiB;
- peak memory первого запуска составил 14.5 GiB.

## 2. Архитектура и компоненты

```text
filesystem sources + application-aware dumps
  -> /mnt/ufiles/.backup-staging/current
  -> encrypted Restic repository /mnt/ufiles/restic/zuer
  -> 7 daily snapshots
  -> weekly check/prune + monthly full check
  -> restore drills
```

Основные пути:

```text
/mnt/ufiles/restic/zuer                 encrypted repository
/mnt/ufiles/.backup-staging            временный root-only staging
/usr/local/sbin/osnova-backup.sh       orchestration
/usr/local/sbin/osnova-backupctl       операции и health checks
/etc/osnova-backup/restic.env          пути Restic
/etc/osnova-backup/restic-password     root-only password
/var/lib/osnova-backup                 timestamps и последний snapshot ID
/var/cache/osnova-backup               Restic cache
```

Systemd units:

```text
osnova-backup.service
osnova-backup.timer
osnova-backup-maintenance@.service
osnova-backup-prune.timer
osnova-backup-check.timer
osnova-backup-check-data.timer
```

Git является источником правды. Runtime разворачивается через
`ansible/backup.yml`, не затрагивая SSH, firewall и desktop.

## 3. Состав snapshot

### Файловые источники

- `/etc`;
- `/home/nsadmin`;
- `/run/media/nsadmin/godny_soft`, включая `.git` и незакоммиченные файлы;
- `/opt/nextcloud`;
- `/srv/proxy/traefik`;
- `/etc/rancher/k3s`.

Restic использует `--one-file-system`. Каждый обязательный filesystem source
передаётся отдельно.

### Nextcloud

- MariaDB dump через `mariadb-dump --single-transaction`;
- archive `/var/www/html` без смонтированного `data`;
- filesystem source `/opt/nextcloud`.

На время dump и archive включается maintenance mode. Cleanup trap выключает
его при success, ошибке, SIGINT и SIGTERM. Целевое окно — не более 900 секунд.

```text
/mnt/ufiles/.backup-staging/current/databases/nextcloud.sql
/mnt/ufiles/.backup-staging/current/nextcloud/application.tar.gz
```

### PostgreSQL

Для `local-pgvector` сохраняются globals и каждая non-template database в
custom format. Каждый `.dump` проходит `pg_restore --list` до snapshot.

```text
/mnt/ufiles/.backup-staging/current/postgresql/local-pgvector/
```

### OpenWebUI и Hermes

Volumes `local_llm_open_webui_data` и `local_llm_open_webui_ai_data`
сохраняются в staging. SQLite копируется через backup API и проходит
`PRAGMA quick_check`; остальные файлы копируются `rsync`.

Optional `local_llm_hermes_data` копируется только как cold volume. Если он
подключён к работающему container, backup останавливается для защиты от
неконсистентной копии.

### k3s и inventory

При активном k3s сохраняются SQLite datastore, server token, Kubernetes
objects и nodes. Дополнительно сохраняются package selections, Docker
containers и volume inventory.

## 4. Исключения и границы защиты

Не сохраняются:

- `/mnt/ufiles/nextcloud-data`;
- Kubernetes PVC/local-path data на `/mnt/ufiles`;
- X-FILES и MEGA FILES;
- Ollama weights и Docker image layers;
- `node_modules`, `.next`, virtualenv, caches, npm cache и Trash;
- сам Restic password.

Repository и часть live-данных находятся на одном `/dev/sdf1`. Отказ диска
может уничтожить и live-данные, и локальный backup. Нужен отдельный
off-site/offline слой для полноценного правила 3-2-1.

## 5. Шифрование и password

```text
/etc/osnova-backup/restic-password
root:root 0600
```

Recovery password сохранён вне ZUER 2026-08-20. Его запрещено помещать в Git,
чат, issue, отчёт или script. Проверять можно только метаданные:

```bash
sudo stat -c '%n %U:%G %a %s bytes' \
  /etc/osnova-backup/restic-password
```

Потеря всех копий password означает необратимую потерю snapshots.

## 6. Расписание

| Операция | Базовое время | Delay | Unit |
|---|---:|---:|---|
| Snapshot | ежедневно 03:20 | до 20 минут | `osnova-backup.timer` |
| Metadata check | суббота 05:15 | до 20 минут | `osnova-backup-check.timer` |
| Retention/prune | воскресенье 05:15 | до 20 минут | `osnova-backup-prune.timer` |
| Full data check | первое воскресенье 06:30 | до 30 минут | `osnova-backup-check-data.timer` |

`Persistent=true` запускает пропущенное задание после включения сервера.

```bash
systemctl list-timers 'osnova-backup*' --all
systemctl is-enabled \
  osnova-backup.timer \
  osnova-backup-prune.timer \
  osnova-backup-check.timer \
  osnova-backup-check-data.timer
```

Все четыре timers включены 2026-08-20.

## 7. Инкрементность и rotation

Каждый запуск виден как полный logical snapshot, но Restic хранит только новые
blocks. Неизменившиеся blocks дедуплицируются.

Политика: `keep 7 daily`, group `host,tags`, host `ZUER`, tag `daily`.
После успешного snapshot выполняется `forget`. Устаревшие physical blocks
удаляет weekly prune с ограничениями:

```text
--max-unused 10%
--max-repack-size 10G
```

Общий `flock` запрещает параллельные backup, prune и checks. Нельзя вручную
удалять файлы внутри Restic repository.

## 8. Safety gates

Операция завершается до snapshot, если:

- `/mnt/ufiles` не отдельный ext4 mount или UUID отличается от
  `548a00f5-dfd3-47d0-9879-b2a175b5bdb1`;
- write-probe в каталоге Restic не проходит;
- на `ufiles` свободно менее 20%, на `/` — менее 15%;
- password/repository недоступны;
- lock уже занят;
- отсутствует обязательный source/container;
- dump пуст или не проходит проверку.

Unit использует `ProtectSystem=strict`. Поэтому корень `/mnt/ufiles` внутри
mount namespace может отображаться `ro`, хотя объявленные `ReadWritePaths`
доступны. Runtime проверяет реальную запись, Ansible отдельно проверяет host
mount как `rw`.

## 9. Ежедневная проверка

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
make backup-status
make backup-snapshots
systemctl list-timers 'osnova-backup*' --all
systemctl --failed
sudo journalctl -u osnova-backup.service -n 100 --no-pager
df -hT /mnt/ufiles /
df -i /mnt/ufiles /
```

`backup-status` возвращает ошибку, если snapshot старше 26 часов, metadata
check старше 192 часов, full check старше 840 часов или capacity ниже порогов.

Для oneshot `inactive (dead)` после завершения нормально. Проверять result:

```bash
systemctl show osnova-backup.service \
  -p ActiveState -p SubState -p Result -p ExecMainStatus
```

Ожидается `Result=success` и `ExecMainStatus=0`.

## 10. Ручной запуск и остановка

```bash
make backup-preflight
systemctl is-active osnova-backup.service
make backup-run
```

Наблюдение из второго terminal:

```bash
sudo journalctl -fu osnova-backup.service
```

Не перезапускать Nextcloud, PostgreSQL, Docker или k3s во время backup.

Аварийная остановка и контроль Nextcloud:

```bash
sudo systemctl stop osnova-backup.service
docker exec -u www-data nextcloud-app-1 php occ maintenance:mode
```

Если maintenance остался включён:

```bash
sudo docker exec -u www-data nextcloud-app-1 \
  php occ maintenance:mode --off
```

## 11. Команды управления

| Команда | Назначение | Изменяет repository |
|---|---|---|
| `make backup-preflight` | Mount, capacity, credentials | только write-probe |
| `make backup-init` | Создать/проверить repository | при первом запуске |
| `make backup-run` | Snapshot и forget | да |
| `make backup-status` | Freshness и health | нет |
| `make backup-snapshots` | Список snapshots | нет |
| `make backup-retention-dry-run` | Preview rotation | нет |
| `make backup-check` | Metadata check | state timestamp |
| `make backup-check-data` | Full read-data check | state timestamp |
| `make backup-prune` | Retention и освобождение blocks | да |
| `make backup-restore-smoke` | Restore `/etc/hostname` | нет |

Контрольный цикл:

```bash
make backup-retention-dry-run
make backup-check
make backup-check-data
make backup-restore-smoke
make backup-status
```

Full check создаёт заметную disk load и не запускается в production peak.

## 12. Восстановление файлов

Не восстанавливать поверх production первым действием. Сначала новый root-only
каталог, review и diff.

```bash
sudo -i
source /etc/osnova-backup/restic.env
export RESTIC_CACHE_DIR=/var/cache/osnova-backup
restic snapshots --host ZUER --tag daily
restore_dir="$(mktemp -d /tmp/zuer-restore.XXXXXX)"
restic restore latest --host ZUER --tag daily \
  --include /etc/hostname --target "$restore_dir"
cmp /etc/hostname "$restore_dir/etc/hostname"
exit
```

Для `godny_soft`:

```bash
sudo -i
source /etc/osnova-backup/restic.env
restore_dir="$(mktemp -d /tmp/zuer-restore.XXXXXX)"
restic restore latest --host ZUER --tag daily \
  --include '/run/media/nsadmin/godny_soft/**' --target "$restore_dir"
rsync -anvi "$restore_dir/run/media/nsadmin/godny_soft/" \
  /run/media/nsadmin/godny_soft/
exit
```

Не использовать `--delete` при первом restore.

## 13. Восстановление PostgreSQL

```bash
sudo -i
source /etc/osnova-backup/restic.env
restore_dir="$(mktemp -d /tmp/zuer-pg-restore.XXXXXX)"
restic restore latest --host ZUER --tag daily \
  --include '/mnt/ufiles/.backup-staging/current/postgresql/**' \
  --target "$restore_dir"
find "$restore_dir" -type f -printf '%p %s bytes\n'
exit
```

`.dump` проверять `pg_restore --list` и импортировать сначала в изолированный
PostgreSQL той же major-version. Globals просмотреть до импорта: они меняют
cluster-wide roles. Production restore требует backup текущей БД, окно простоя,
новую пустую БД, `pg_restore --exit-on-error`, smoke test и rollback. Удаление
рабочей БД без отдельного подтверждения запрещено.

## 14. Восстановление Nextcloud

```bash
sudo -i
source /etc/osnova-backup/restic.env
restore_dir="$(mktemp -d /tmp/zuer-nextcloud-restore.XXXXXX)"
restic restore latest --host ZUER --tag daily \
  --include '/mnt/ufiles/.backup-staging/current/databases/nextcloud.sql' \
  --include '/mnt/ufiles/.backup-staging/current/nextcloud/**' \
  --include '/opt/nextcloud/**' --target "$restore_dir"
gzip -t "$restore_dir/mnt/ufiles/.backup-staging/current/nextcloud/application.tar.gz"
test -s "$restore_dir/mnt/ufiles/.backup-staging/current/databases/nextcloud.sql"
exit
```

Dump сначала импортируется в изолированную MariaDB совместимой версии. Полный
DR невозможен без отдельной копии `/mnt/ufiles/nextcloud-data`. Production
restore требует maintenance mode, backup текущего состояния и application
smoke test. Может потребоваться `occ maintenance:data-fingerprint`.

## 15. OpenWebUI, Hermes и k3s

OpenWebUI/Hermes сначала восстановить для review:

```bash
sudo -i
source /etc/osnova-backup/restic.env
restore_dir="$(mktemp -d /tmp/zuer-app-restore.XXXXXX)"
restic restore latest --host ZUER --tag daily \
  --include '/mnt/ufiles/.backup-staging/current/openwebui/**' \
  --include '/mnt/ufiles/.backup-staging/current/cold-volumes/**' \
  --target "$restore_dir"
find "$restore_dir" -type f -name '*.db' -print0 |
  while IFS= read -r -d '' sqlite_db; do
    sqlite3 "$sqlite_db" 'PRAGMA quick_check;'
  done
exit
```

Перед заменой Docker volume остановить stack и сохранить текущий volume.
Удаление volumes без подтверждения запрещено.

k3s snapshot содержит:

```text
/mnt/ufiles/.backup-staging/current/k3s/state.db
/mnt/ufiles/.backup-staging/current/k3s/server-token
```

Сначала восстановить в review-каталог и выполнить SQLite quick check. Замена
рабочего datastore требует подтверждения SQLite backend, остановки k3s, backup
текущего state/token, проверки permissions, запуска и smoke test nodes/pods/PV.

## 16. Диагностика

```bash
systemctl status osnova-backup.service --no-pager --full
sudo journalctl -u osnova-backup.service -n 200 --no-pager -o short-iso
make backup-preflight
df -hT /mnt/ufiles /
df -i /mnt/ufiles /
```

- При недостатке места не обходить threshold: выполнить retention dry-run,
  затем штатный prune. Не удалять `data`, `index`, `keys`, `snapshots`, `config`.
- При неверном UUID не писать backup в обычный каталог `/`; проверить
  `findmnt /mnt/ufiles` и `lsblk -f`.
- При занятом lock проверить service, jobs и `ps -ef | grep '[r]estic'`.
  `restic unlock` допустим только когда процессов точно нет.
- При dump error исправить приложение/БД; не копировать live DB directory.
- Если Nextcloud maintenance включён, выключить его и сохранить journal.

## 17. Изменение и rollback

Настройки изменяются только в Git:

```bash
git branch --show-current
git status --short
make backup-static-check
make backup-ansible-check
make backup-ansible-apply
make backup-preflight
```

После добавления source/database/volume обязателен ручной snapshot и restore
drill именно нового компонента.

Декларативное выключение: установить `backup_timer_enabled: false`, затем
check/diff и apply. Аварийное выключение:

```bash
sudo systemctl disable --now \
  osnova-backup.timer \
  osnova-backup-prune.timer \
  osnova-backup-check.timer \
  osnova-backup-check-data.timer
```

Repository при rollback не удалять.

## 18. Legacy и disaster recovery

Сохранены legacy generations:

```text
/mnt/ufiles/backups/2026-08-07_03-23-22
/mnt/ufiles/backups/2026-08-08_03-22-02
```

Не удалять их до семи успешных daily Restic snapshots и повторного restore
drill. Любому удалению предшествует:

```bash
./scripts/backup/prune-osnova-backups.sh --dry-run
```

При потере сервера, но сохранном `/dev/sdf1`: установить Restic, восстановить
password file из внешней копии, указать environment, выполнить snapshots/check
и восстанавливать сначала в новый filesystem. При отказе самого `/dev/sdf1`
локальной копии недостаточно.

## 19. RPO, RTO и следующие улучшения

- RPO: до 24 часов плюс randomized delay до 20 минут.
- Health threshold: 26 часов без успешного snapshot.
- RTO полного сервера пока не измерен и не подтверждён.
- Golden backup занял 5:08, но это не full restore RTO.

Приоритеты:

1. Off-site/offline encrypted copy.
2. Alerts на failed unit, snapshot старше 26 часов и free space ниже 20%.
3. Контроль peak memory следующих incremental runs.
4. Через 30 дней оценить churn и расширить off-site retention до
   `7 daily + 4 weekly + 6 monthly`.
5. Отдельный backup Nextcloud data на другом физическом носителе.
