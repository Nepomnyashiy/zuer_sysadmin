# Ход-отчёт: аудит системы резервного копирования ZUER

Дата: 2026-08-06

## Цель

Проверить фактическое покрытие резервным копированием, отдельно подтвердить
backup `godny_soft` и предложить безопасную целевую архитектуру.

## Что сделано

- Проверены активные systemd timer/service и их журнал.
- Проверены текущие и legacy backup-скрипты.
- Измерен `godny_soft` и состав последней копии.
- По сохранённому Docker inventory определены live containers и volumes.
- Проверены Kubernetes PV/PVC и отсутствие backup CronJob.
- Проверены права secret-файлов без чтения их содержимого.
- Создан эксплуатационный runbook и целевая схема.

## Изменённые файлы

- `docs/runbooks/backup-system.md`
- `docs/reports/2026-08-06-backup-system-audit.md`

Изменения retention, подготовленные ранее в `ansible/group_vars/all.yml` и
`ansible/templates/osnova-backup.sh.j2`, не развёртывались в runtime.

## Выполненные команды

```text
systemctl status osnova-backup.timer osnova-backup.service --no-pager
systemctl list-timers --all --no-pager
journalctl -u osnova-backup.service -n 80 --no-pager
kubectl get nodes,pods,pvc,pv,cronjobs,jobs
du -x -h --max-depth=1 /run/media/nsadmin/godny_soft
du -x -h --max-depth=2 /mnt/ufiles/daily_backups
jq ... /mnt/ufiles/backups/latest/docker-ps.jsonl
jq ... /mnt/ufiles/backups/latest/docker-volumes.jsonl
find ... .git/.env/compose files
```

## Проверки

- `osnova-backup.timer` активен; последний запуск завершён успешно.
- `godny_soft` занимает около 13 GiB, последняя фильтрованная копия — около
  6.7 GiB.
- `godny_soft` входит в текущий backup, но `.git` исключён.
- Найдено девять Git repositories; только `.git` двух крупнейших занимает
  около 1.6 GiB.
- Legacy `/mnt/ufiles/daily_backups` занимает около 44 GiB и не обновлялся с
  марта 2026 года.
- Kubernetes содержит только registry PVC; CronJob backup отсутствуют.
- Действующие Docker database/data volumes не получают консистентные dumps.
- Часть `.env` имеет mode `0664` и попадает в незашифрованные копии.

## Результат

Текущий backup полезен как ежедневная файловая копия system/home/`godny_soft`,
но не обеспечивает полноценное восстановление Nextcloud, Docker databases,
k3s state и данных, расположенных на самом `/mnt/ufiles`.

Рекомендована staged-модель: application-aware dumps, encrypted deduplicated
Restic snapshots, отдельный физический носитель, off-site/offline копия и
регулярные restore tests.

## Найденные проблемы

- Backup и часть live-данных разделяют `/dev/sdf1`.
- Нет off-site/offline копии.
- Нет dumps Nextcloud MariaDB и работающих PostgreSQL.
- Нет backup части Docker volumes, Traefik ACME и k3s datastore.
- Полные rsync-поколения не используют дедупликацию.
- Emergency retention из двух копий слишком короткий для постоянной работы.
- `rsync code 24` уже приводил к падению backup из-за изменяющихся browser
  files.
- Нет alerts, формального RPO/RTO и доказанного restore drill.

## Риски

- Отказ `/dev/sdf1` затронет и live-данные, и локальную копию.
- Plaintext backup содержит локальные `.env`.
- Успешный filesystem copy не гарантирует консистентность live database.
- Полный диск может нарушить Nextcloud, Docker и Kubernetes workloads.

## Что осталось

1. Выполнить ранее подтверждённый prune старых полных поколений.
2. Разместить runbook как `/mnt/ufiles/backups/README.md` с root-правами.
3. Выбрать off-site/offline backend.
4. Согласовать RPO/RTO и классификацию `x-files`/`mega-files`.
5. Спроектировать и протестировать database dump jobs.
6. Выполнить пилот Restic для `godny_soft`.
7. Провести restore drill до отключения legacy backup.

## Следующий шаг

Пилотировать encrypted Restic backup `godny_soft` на отдельный repository с
включёнными `.git` и исключёнными rebuildable dependencies. После restore test
подключить database dumps и off-site repository.

## Rollback

В этой итерации runtime backup не изменялся. Добавленные Markdown-файлы можно
удалить из Git без влияния на действующий timer. Миграцию backup выполнять
параллельно со старой системой до успешного restore drill.
