# Ход-отчёт: оптимизация sdc2

Дата: 2026-08-20

## Цель

Определить причины заполнения системного раздела `/dev/sdc2`, безопасно
освободить воспроизводимые данные и подготовить перенос Docker containerd image
store на `/mnt/ufiles`.

## Что сделано

- Выполнена инвентаризация filesystem, Docker, k3s, Ollama, home, Snap и logs.
- Принято решение оставить Docker volumes и swap на SSD.
- Подготовлены audit/GC/migration/rollback/finalize scripts.
- Добавлен отдельный Ansible-playbook для containerd root, mount dependency и
  Docker log rotation.
- Создан ADR и runbook миграции.

## Исходное состояние

- `/dev/sdc2`: 109 GiB, занято 86 GiB, доступно 18 GiB, заполнение 84%.
- `/mnt/ufiles`: 916 GiB, занято 234 GiB, доступно 636 GiB.
- Docker images: 169, 42.78 GB, reclaimable 9.519 GB.
- Dangling images: 118.
- Build cache: 6.228 GB, до GC Docker показывал 0 B reclaimable.
- Docker volumes: 3.808 GB, преимущественно активные данные.
- Ollama models: 79.8 GB, уже находятся на `ufiles`.
- k3s images: около 262 MB; registry PVC находится на `ufiles`.
- `/home/nsadmin`: 15.66 GB; крупнейший отдельный файл — Chrome on-device
  model 4.27 GB.
- Journald: 695.5 MB; Snap images: 3.786 GB, около 1.8 GB отключённых ревизий.

## Изменённые файлы

- `ansible/container-runtime-storage.yml` и четыре templates.
- `scripts/storage/`.
- `Makefile`, `ansible/group_vars/all.yml`.
- ADR-0006 и runbook containerd migration.

## Проверки

- Shell syntax, Ansible syntax, rendered Docker JSON и containerd config
  успешно проверены.
- Storage audit подтвердил `rw`, UUID и свободное место `ufiles`.
- Docker GC удалил 114 из 118 dangling images старше семи дней; четыре более
  новых dangling image сохранены.
- После GC сохранены все 22 containers, 12 volumes и 13 running containers.
- Docker GC снизил заполнение `/` с 84% до 74%.
- Удалены только четыре согласованных воспроизводимых user-cache/model
  каталога общим размером около 7 GiB; профили и Downloads сохранены.
- После user-cache cleanup `/` занимает 67%, доступно 35 GiB.

## Найденные проблемы

- `sudo` требует интерактивной аутентификации; root migration нельзя выполнять
  без участия администратора.
- `snap list --all` не завершился за приемлемое время при preview; Snap cleanup
  не выполнялся и теперь защищён обязательным 30-секундным timeout.
- `ufiles` — HDD и единый failure domain для LLM, Kubernetes PVC и local backup.
- Большинство существующих Docker containers используют `json-file` без
  ротации; глобальные defaults применятся после их планового recreate.
- Первая cold migration остановилась до изменения runtime config: в пакетной
  установке отсутствовал каталог `/etc/containerd`, и Ansible template не мог
  создать файл. System containerd/Docker были запущены на прежнем root, после
  чего вручную восстановлен точный baseline из 13 running containers.
- Playbook исправлен: `/etc/containerd` создаётся декларативно. Migration script
  теперь имеет EXIT-recovery, который при любой ошибке во время downtime
  восстанавливает исходные configs, сервисы и сохранённый running set.
- Повторная cold migration успешно переключила system containerd на
  `/mnt/ufiles/container-runtime/containerd`. Post-check завершился ошибкой,
  потому что `local-open-webui-ai` оставался `health: starting` дольше 120
  секунд; сервис самостоятельно стал healthy и стабильно отвечает HTTP 200.
- Health timeout увеличен до 10 минут и добавлена отдельная post-migration
  команда `containerd-storage-verify`, не выполняющая повторный downtime/copy.
- Read-only post-check подтвердил новый containerd root на `ufiles`, 13 из 13
  прежних running containers, healthy Open WebUI/pgvector/prombiztech,
  доступность Ollama API, обеих Open WebUI, Nextcloud и Black Mamba API, а также
  Ready node и пять Running Kubernetes pods.
- Root-команда `make containerd-storage-verify` завершилась; migration state
  прошёл итоговую проверку и переведён в 24-часовой soak перед finalize.

## Что осталось

- Пройти SMART/backup preflight с root-доступом.
- Завершить 24-часовой soak и выполнить finalize с отдельным подтверждением.
- Удалить отключённые Snap revisions, сократить journal до 300 MB и выполнить
  apt clean с root-доступом после восстановления нормального ответа snapd.
- После отдельного подтверждения удалить старый `/var/lib/containerd`.

## Rollback

До finalize используется `make containerd-storage-rollback`. После finalize
потребуется скопировать image store с `ufiles` обратно на SSD.
