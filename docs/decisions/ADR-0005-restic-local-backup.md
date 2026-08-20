# ADR-0005: Инкрементные backup ZUER через Restic

Дата: 2026-08-19
Статус: accepted

## Контекст

Ежедневный `rsync` создавал независимые полные поколения на `/mnt/ufiles` без
работающего retention. 46 поколений заполнили `/dev/sdf1` объёмом 916 GiB.
Последний подтверждённый backup завершился 2026-08-08.

На `ufiles` одновременно находятся backup и live-данные Nextcloud, Ollama и
Kubernetes local-path. Пользователь выбрал `/mnt/ufiles` как локальный target и
подтвердил, что live-данные этого же filesystem не должны дублироваться в нём.

## Решение

- Использовать зашифрованный Restic repository `/mnt/ufiles/restic/zuer`.
- Создавать один application-aware snapshot в сутки.
- Хранить семь ежедневных snapshots.
- Выполнять `forget` после успешного snapshot, `prune` еженедельно, metadata
  check еженедельно и полный read-data check ежемесячно.
- До snapshot создавать согласованные MariaDB, PostgreSQL, OpenWebUI SQLite и
  k3s SQLite copies в root-only staging на `ufiles`.
- Включать Nextcloud maintenance mode не более чем на целевые 15 минут и всегда
  выключать его через cleanup trap.
- Не сохранять X-FILES, MEGA FILES, Ollama models, container image layers,
  caches и live-данные, уже расположенные на `ufiles`.
- Не включать systemd timers, пока recovery key не сохранён вне ZUER и не
  выполнен restore drill.

## Почему

Restic дедуплицирует одинаковые блоки между snapshots, шифрует repository,
проверяет целостность и предоставляет штатную retention-модель. Logical dumps
и SQLite backup API надёжнее копирования открытых файлов баз.

## Альтернативы

- Полные `rsync`-поколения: отклонены из-за линейного роста и отсутствия
  дедупликации.
- Borg: технически подходит, но Restic уже установлен и проще переносится на
  будущий S3/off-site target.
- Backup всех data-дисков на `ufiles`: невозможен по ёмкости и создаёт ложную
  защиту для live-данных самого `/dev/sdf1`.

## Последствия

- RPO составляет до 24 часов; retention — семь дней.
- Локальная история защищает от логического удаления данных с других дисков.
- Отказ `/dev/sdf1` по-прежнему уничтожит repository и live-данные на `ufiles`.
- Для полноценной схемы 3-2-1 потребуется отдельная off-site/offline копия.

## Риски

- Потеря Restic password делает repository невосстановимым.
- Nextcloud data и Kubernetes PVC на `ufiles` не защищены от отказа диска.
- `prune` требует дополнительного свободного места для repack и не должен
  запускаться при заполненном filesystem.

## Rollback

Остановить новые timers, вернуть предыдущие systemd templates и использовать
сохранённые legacy-поколения. Restic repository не удалять: он не мешает
rollback и может понадобиться для восстановления.
