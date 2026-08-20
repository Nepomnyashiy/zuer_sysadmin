# ADR-0006: Docker containerd image store на ufiles

Дата: 2026-08-20
Статус: accepted

## Контекст

Корневой SSD `/dev/sdc2` размером 109 GiB заполнен на 84%. Docker Engine 29
использует системный containerd image store: 169 образов занимают 42.78 GB, а
данные образов и snapshots находятся в `/var/lib/containerd`. На ext4-диске
`/mnt/ufiles` свободно около 636 GiB, но это механический HDD.

Ollama models и Kubernetes local-path уже находятся на `ufiles`. Docker named
volumes содержат Nextcloud, Open WebUI, MariaDB и PostgreSQL данные и должны
остаться на системном SSD.

## Решение

Перенести только persistent root системного containerd в
`/mnt/ufiles/container-runtime/containerd`. Оставить transient state в
`/run/containerd`, Docker `data-root` и named volumes — в `/var/lib/docker`.

Перед containerd/Docker systemd обязан смонтировать `ufiles` и проверить
mountpoint. Миграция выполняется cold copy после проверенного backup. Старый
root хранится 24 часа и удаляется только после отдельного подтверждения.

## Почему

- image layers воспроизводимы из registry/Dockerfile;
- перенос освобождает десятки GB на системном SSD;
- stateful volumes не смешиваются с image cache и локальным backup-диском;
- настройка `root` является штатным интерфейсом containerd.

## Альтернативы

- Только Docker GC: безопаснее, но рост image store снова заполнит SSD.
- Перенос всего `/var/lib/docker`: отклонён из-за переноса баз на HDD и в
  единый failure domain с backups.
- Перенос swap: отклонён из-за ухудшения поведения при memory pressure.

## Последствия

- pull, unpack, build и холодный старт образов могут стать медленнее;
- отказ `ufiles` остановит Docker, но k3s использует отдельный embedded
  containerd;
- named volumes остаются на SSD и требуют существующей backup-процедуры.

## Риски

- `ufiles` — single HDD, не отказоустойчивое хранилище;
- неверный mount может привести к записи в пустой каталог системного диска;
- удаление старого containerd root до soak лишит быстрого rollback.

## Rollback

До finalize остановить Docker/containerd, восстановить прежний
`/etc/containerd/config.toml` и systemd override, затем запустить runtime на
неизменённом `/var/lib/containerd`.
