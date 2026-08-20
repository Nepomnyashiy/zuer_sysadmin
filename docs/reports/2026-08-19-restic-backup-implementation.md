# Ход-отчёт: реализация Restic backup ZUER

Дата: 2026-08-19

## Цель

Подготовить декларативную инкрементную backup-систему на `/mnt/ufiles` с
application-aware dumps, retention, проверками целостности и restore smoke.

## Что сделано

- Полный rsync-шаблон заменён Restic orchestration.
- Добавлены MariaDB, PostgreSQL, OpenWebUI SQLite и k3s SQLite backup stages.
- Добавлены preflight по mount UUID, filesystem type, `rw` и свободному месту.
- Добавлены ежедневный backup, weekly prune/check и monthly full-check units.
- Добавлен `osnova-backupctl` и Makefile-интерфейс.
- Добавлена безопасная обработка legacy partial-каталогов.
- Добавлен изолированный `ansible/backup.yml`, чтобы rollout не применял
  несвязанные настройки SSH, firewall, Docker и desktop.
- Исправлен preflight в Ansible check mode: безопасный read-only `findmnt`
  выполняется и при `--check`, а пустой или некорректный вывод обрабатывается
  как понятная ошибка проверки mount.
- После первого `backup-init` исправлена несовместимая комбинация GNU `df -P
  --output`; parser теперь валидирует числовой результат, а static-check содержит
  regression guard. Repository при обнаружении дефекта успешно создался.
- Первый service start остановился на preflight до обработки приложений:
  `ProtectSystem=strict` ожидаемо показывал корень `/mnt/ufiles` как `ro` внутри
  mount namespace, хотя разрешённые `ReadWritePaths` доступны. Проверка OPTIONS
  заменена реальной временной write-probe в родительском каталоге Restic;
  строгая systemd sandbox-защита сохранена. Nextcloud maintenance не включался.
- Activation gate не позволяет включить timers до offline-copy recovery key и
  restore drill.
- Старый runtime `osnova-backup.timer` остановлен и отключён 2026-08-20 после
  очередного падения с `No space left on device`.
- Созданы ADR и отдельный rollout/restore runbook.

## Изменённые файлы

- Ansible backup variables, tasks и templates.
- `Makefile` и `scripts/backup/`.
- ADR, runbook и этот отчёт.

## Выполненные команды

```text
git branch --show-current
git status --short
git log --oneline -10
ansible template ...
bash -n ...
make backup-static-check
ansible-playbook ... --syntax-check
restic ... --help
systemd-analyze calendar ...
systemctl stop osnova-backup.timer
systemctl disable osnova-backup.timer
```

## Проверки

- Оба shell templates успешно рендерятся и проходят `bash -n`.
- Все systemd calendar expressions распознаются.
- Используемые Restic flags поддерживаются установленной версией 0.18.1.
- `ansible/bootstrap.yml` и `ansible/backup.yml` проходят syntax-check.
- Backup static check воспроизводим через Makefile.

## Результат

Код новой системы подготовлен в Git worktree. Неисправный старый timer
остановлен. После успешного изолированного Ansible dry-run новая backup-система
развёрнута 2026-08-20: установлены runtime packages, scripts, environment и
systemd units, создан root-only Restic password. После сохранения recovery key,
golden snapshot и restore drill все timers декларативно включены.

После подтверждённого запуска cleanup пользователем 2026-08-20:

- `/mnt/ufiles` занимает 26% (`221G`), доступно `650G`;
- inode usage составляет 2%; сохранены последние два legacy-поколения;
- `latest` указывает на `2026-08-08_03-22-02`, контрольный файл читается;
- mount проверен вне sandbox: `ext4`, ожидаемый UUID, режим `rw`;
- старый `osnova-backup.timer` имеет состояния `disabled` и `inactive`;
- все четыре новых timer имеют состояния `disabled` и `inactive`;
- Restic 0.18.1 и новые scripts установлены с ожидаемыми владельцами и правами;
- после удаления только неиспользуемого Docker build cache корень занимает 84%,
  доступно `18G`, то есть preflight-порог 15% выполнен.
- Первый golden snapshot `c2ad12e1` создан 2026-08-20 13:04 MSK и завершён
  успешно за 5 минут 8 секунд; logical snapshot size — 18.1 GiB.
- После snapshot `/mnt/ufiles` занимает 27% (`234G`), доступно `636G`;
  Nextcloud maintenance выключен, service имеет `Result=success`.
- Retention dry-run сохраняет snapshot по политике `keep 7 daily`.
- `restic check` и полный `restic check --read-data` (832 packs) завершились без
  ошибок; restore smoke восстановил и сравнил `/etc/hostname`.
- Итоговый `osnova-backupctl status`: healthy, latest snapshot `c2ad12e1`.
- Пользователь подтвердил внешнее сохранение recovery password; activation gate
  переключён для декларативного включения timers.
- Финальный Ansible apply завершён без ошибок; четыре timers имеют состояние
  `enabled`. Ближайшие рассчитанные запуски: daily 2026-08-21 03:36,
  metadata check 2026-08-22 05:30, prune 2026-08-23 05:24 и full check
  2026-09-06 06:34 MSK.

## Найденные проблемы

- Первый запуск потребовал 14.5G peak memory; это нужно учитывать при расписании
  и наблюдать на следующих инкрементных запусках.
- Nextcloud data и Kubernetes PVC находятся на самом `ufiles` и не защищаются
  локальным repository от отказа `/dev/sdf1`.

## Риски

- Legacy cleanup необратим.
- Потеря Restic password делает snapshots недоступными.
- Локальный repository не заменяет off-site/offline backup.

## Что осталось

1. Проверить первый автоматический ежедневный запуск 2026-08-21.
2. Добавить отдельную off-site/offline копию repository для защиты от отказа
   `/dev/sdf1`.

## Следующий шаг

Проверить `make backup-status` и journal после первого автоматического запуска.

## Rollback

Изменить `backup_timer_enabled: false`, выполнить Ansible `--check --diff` и
apply. Для аварийной остановки отключить четыре `osnova-backup*` timer.
Restic repository и golden snapshot не удалять.
