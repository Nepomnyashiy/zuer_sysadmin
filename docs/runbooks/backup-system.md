# Резервное копирование ZUER: инструкция и целевая схема

> Исторический документ аудита и переходного дизайна от 2026-08-06.
> Действующая production-инструкция:
> `docs/runbooks/restic-backup-system.md`.

Дата актуализации: 2026-08-06

## Назначение

Этот документ описывает текущую систему резервного копирования ZUER, её
ограничения, безопасные ежедневные операции и целевую схему модернизации.

Backup считается рабочим только после успешной проверки восстановления.
Наличие каталога или успешного systemd unit само по себе восстановление не
гарантирует.

## Критически важное предупреждение

Каталог `/mnt/ufiles/backups` находится на том же физическом диске `/dev/sdf1`,
что и live-данные Nextcloud, Docker и Kubernetes. Отказ `/dev/sdf1` может
одновременно уничтожить live-данные и локальные копии этих данных.

Локальная копия на `/mnt/ufiles` полезна для восстановления данных с других
дисков, включая `godny_soft`, но не является достаточным backup для данных,
которые сами находятся на `/mnt/ufiles`.

## Текущее состояние

Активный timer:

```bash
systemctl status osnova-backup.timer --no-pager
systemctl list-timers osnova-backup.timer --all --no-pager
```

Расписание: один раз в сутки около `03:20`, с рандомизированной задержкой до
20 минут. `Persistent=true` означает, что пропущенный во время выключения запуск
будет выполнен после старта системы.

Текущий backup копирует:

- `/etc`;
- `/home/nsadmin`;
- `/run/media/nsadmin/godny_soft`;
- `/opt/nextcloud`;
- список пакетов;
- список контейнеров и Docker volumes.

Текущие исключения:

- `.git/`;
- `node_modules/`;
- `.next/`;
- `venv/`, `.venv/`;
- `__pycache__/`, `.cache/`;
- `ollama_models/`.

`godny_soft` уже копируется, но без Git-метаданных. Это сохраняет рабочие файлы,
однако не сохраняет локальные ветки, commits, tags, reflog и Git configuration,
которые отсутствуют в удалённом Git-сервере.

## Что сейчас не защищено полностью

- MariaDB Nextcloud (`nextcloud_db`) — нет `mariadb-dump`.
- Docker volume приложения Nextcloud (`nextcloud_nextcloud`).
- Файлы Nextcloud в `/mnt/ufiles/nextcloud-data` — backup на другом диске
  отсутствует.
- PostgreSQL Black Mamba (`local_llm_postgres_data`) — нет `pg_dump`.
- OpenWebUI data volumes.
- Hermes data volume в установленной runtime-версии скрипта.
- PostgreSQL Prombiztech (`prombiztech-dev_postgres_data`) — нет `pg_dump`.
- Live Traefik configuration и ACME storage в `/srv/proxy/traefik`.
- Состояние k3s datastore и документированная процедура его восстановления.
- Данные `/srv/storage/x-files` и `/srv/storage/mega-files`.
- Off-site или offline копия.

## Безопасная ежедневная проверка

Проверить timer и последний запуск:

```bash
systemctl status osnova-backup.timer --no-pager
systemctl status osnova-backup.service --no-pager
journalctl -u osnova-backup.service -n 100 --no-pager
```

Проверить свободное место и последний backup:

```bash
df -hT /mnt/ufiles
find /mnt/ufiles/backups -mindepth 1 -maxdepth 1 \
  -type d -name '????-??-??_??-??-??' -printf '%TY-%Tm-%Td %TH:%TM\t%f\n' \
  | sort
readlink -f /mnt/ufiles/backups/latest
```

Успешным считается запуск, для которого одновременно выполнены условия:

1. `osnova-backup.service` завершился с `status=0/SUCCESS`.
2. `latest` указывает на существующий каталог.
3. В каталоге присутствуют ожидаемые источники.
4. На диске осталось безопасное свободное место.
5. Выполнена хотя бы выборочная проверка чтения файлов.

## Ручной запуск текущего backup

Перед запуском:

```bash
findmnt -T /mnt/ufiles -no TARGET,SOURCE,FSTYPE,OPTIONS
df -hT /mnt/ufiles
systemctl is-active osnova-backup.service
```

Запуск и наблюдение:

```bash
sudo systemctl start osnova-backup.service
journalctl -fu osnova-backup.service
```

Не запускайте второй backup параллельно. Не запускайте backup при почти полном
`/mnt/ufiles`: root может занять зарезервированные ext4-блоки и повредить работе
live-сервисов на этом же диске.

## Retention текущих полных копий

Аварийная временная политика — сохранить две последние полные копии. Сначала
выполняется dry-run:

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
./scripts/backup/prune-osnova-backups.sh --dry-run
```

После проверки списка:

```bash
sudo ./scripts/backup/prune-osnova-backups.sh --apply
```

Удаление необратимо. Скрипт проверяет `latest`, сохраняет две новые копии и
отказывается удалять данные во время активного `osnova-backup.service`.

Две копии — только аварийная мера для освобождения места. Это слишком короткое
окно для постоянной backup-политики.

## Восстановление `godny_soft` из текущей копии

Сначала убедитесь, что источник и назначение разрешены правильно:

```bash
latest="$(readlink -f /mnt/ufiles/backups/latest)"
test -d "$latest/godny_soft"
```

Выполните только dry-run. Завершающий `/` у source важен:

```bash
rsync -anvi "$latest/godny_soft/" /run/media/nsadmin/godny_soft/
```

Не используйте `--delete` при первом восстановлении. Сначала восстанавливайте в
отдельный каталог и сравнивайте файлы. Поскольку `.git/` сейчас исключён, этот
backup не может полноценно восстановить Git repositories.

Пример безопасного восстановления в отдельный каталог:

```bash
mkdir -p /tmp/godny-soft-restore
rsync -a "$latest/godny_soft/" /tmp/godny-soft-restore/
```

Перенос восстановленных файлов обратно выполняется только после проверки diff и
явного подтверждения владельца системы.

## Старый `daily_backups`

`/mnt/ufiles/daily_backups` — устаревшее одиночное зеркало `/home/nsadmin` и
`/etc`. Оно не является инкрементальным backup и не имеет исторических точек.
Удаление файла в source может удалить его из зеркала при следующем `rsync
--delete`.

На 2026-08-06 установленный `/usr/local/bin/daily_backup.sh` отсутствует, а
данные зеркала последний раз обновлялись в марте 2026 года. Каталог занимает
около 44 GiB. Удалять его можно только после restore-проверки новой системы и
отдельного подтверждения.

## Целевая архитектура

Рекомендуемый инструмент — Restic: он уже установлен, шифрует repository,
делает дедупликацию и поддерживает одинаковый workflow для локального и
удалённого storage.

Целевая цепочка:

```text
application-aware dumps
  -> проверяемый staging
  -> encrypted Restic repository на отдельном локальном диске
  -> вторая encrypted копия off-site или на отключаемом носителе
  -> регулярный restore test
```

Необходимо соблюдать правило 3-2-1:

- рабочие данные;
- локальная копия на другом физическом диске;
- одна off-site или offline копия.

`x-files`, `mega-files` и `ufiles` находятся в одном сервере, поэтому копии
между ними защищают от отказа одного диска, но не от кражи, пожара, ошибочного
административного действия или ransomware на ZUER.

## Рекомендуемая политика хранения

После перехода на дедуплицируемые snapshots начать с:

- 7 daily;
- 4 weekly;
- 6 monthly;
- 2 yearly для off-site repository.

Политику корректировать после 30 дней измерения реального daily churn. Prune
выполнять только после успешного нового snapshot и проверки repository.

## Требуемые application-aware backup

### PostgreSQL

Использовать `pg_dump -Fc` для каждой важной базы. Dump должен завершиться
успешно, иметь ненулевой размер и проходить `pg_restore --list`.

Копирование live-каталога `/var/lib/postgresql/data` не считается надёжным
логическим backup.

### MariaDB Nextcloud

Использовать `mariadb-dump --single-transaction`. Для полного согласованного
restore нужны вместе:

- database dump;
- `/opt/nextcloud` и secrets;
- `nextcloud_nextcloud` volume;
- `/mnt/ufiles/nextcloud-data`;
- одинаковая точка времени или короткий maintenance mode.

### Redis

Если Redis используется только как cache/session backend и данные могут быть
пересозданы, его можно не сохранять. Это решение должно быть зафиксировано для
каждого приложения.

### Kubernetes

До появления stateful приложений достаточно хранить manifests, Secrets в
выбранной защищённой системе и registry strategy. Перед переносом PostgreSQL в
Kubernetes нужны отдельные CronJob dumps, retention и restore drill.

Для k3s сначала определить фактический datastore. Процедуры embedded etcd и
SQLite различаются; нельзя применять `k3s etcd-snapshot` без проверки backend.

## `godny_soft`: рекомендуемый состав

Сохранять:

- весь source tree;
- `.git` directories;
- `.env` и другие локальные secrets только внутри зашифрованного repository;
- документацию, migrations, compose/manifests и локальные незакоммиченные
  файлы.

Не сохранять rebuildable data:

- `node_modules`;
- `.next` build output;
- Python virtualenv;
- Go module cache;
- `__pycache__` и обычные caches;
- локальные model weights, если они гарантированно повторно загружаются.

Дополнительно все Git repositories должны регулярно отправлять commits во
внешний Git remote. Git remote дополняет backup, но не заменяет его: untracked,
uncommitted files и secrets туда обычно не попадают.

## Secrets и права

Сейчас часть `.env` имеет mode `0664` и копируется на backup-диск без
шифрования. Необходимо:

1. Привести secret-файлы к `0600`.
2. Сделать backup repository root-only (`0700`).
3. Использовать encrypted Restic repository.
4. Хранить пароль repository вне Git, с отдельной аварийной копией ключа.
5. Никогда не выводить secret values в logs и отчёты.

Без сохранённого Restic password восстановление зашифрованной копии невозможно.

## Контроль места и отказов

До каждого backup проверять:

- все обязательные mount points;
- filesystem в режиме `rw`;
- минимум 15% свободного места;
- отсутствие другого backup-процесса;
- успешность database dumps.

Добавить alerts:

- последний успешный backup старше 26 часов;
- свободное место ниже 20% warning / 10% critical;
- backup unit завершился с ошибкой;
- repository check завершился с ошибкой;
- off-site copy не обновлялась.

Для systemd service рекомендуется `UMask=0077`, низкий IO priority, разумный
timeout и `OnFailure` notification. Лог должен иметь rotation либо храниться
только в journald.

## Проверка восстановления

Ежемесячно:

1. Восстановить случайный набор файлов `godny_soft` во временный каталог.
2. Проверить checksum и открыть несколько файлов.
3. Выполнить `pg_restore --list` для PostgreSQL dumps.
4. Выполнить тестовый restore одной БД в изолированный контейнер.
5. Зафиксировать длительность, результат и обнаруженные проблемы.

Ежеквартально выполнять полный restore drill ключевого приложения. Для каждого
сервиса зафиксировать RPO, RTO и владельца процедуры.

## Безопасный порядок внедрения

1. Освободить место, сохранив две последние текущие копии.
2. Проверить восстановление `godny_soft` и одного конфигурационного файла.
3. Закрыть права на secrets и backup directories.
4. Добавить dumps Nextcloud MariaDB и работающих PostgreSQL.
5. Создать encrypted local Restic repository на отдельном диске.
6. Включить `godny_soft` вместе с `.git`, исключив rebuildable directories.
7. Добавить off-site/offline repository.
8. Настроить retention, repository checks, alerts и restore drills.
9. Только после подтверждения новой системы вывести из эксплуатации legacy
   full-copy и `/mnt/ufiles/daily_backups`.
