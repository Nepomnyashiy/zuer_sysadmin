# Runbook: перенос Docker image store на ufiles

## Назначение

Процедура переносит persistent root системного containerd с SSD
`/var/lib/containerd` на HDD `/mnt/ufiles/container-runtime/containerd`.
Docker volumes, k3s containerd и Ollama models не перемещаются.

Ожидаемое окно недоступности Docker-сервисов — до 60 минут. Маршрутизация
Traefik, Nextcloud, Open WebUI, Ollama и другие Docker workloads в это время
недоступны. Kubernetes продолжает работать.

## Инвентаризация и GC

```bash
make storage-audit
make docker-prune-plan
make docker-prune-apply
make system-cache-plan
sudo make system-cache-apply
make storage-audit
```

Prune удаляет только dangling images и неиспользуемый build cache старше семи
дней. Containers, volumes и tagged images команда не удаляет.

System cache cleanup штатно удаляет только отключённые Snap revisions,
ограничивает journal до 300 MB и очищает APT package cache.

## Root preflight

Установить SMART tooling через декларативный bootstrap или отдельно:

```bash
sudo apt-get install smartmontools
sudo make containerd-storage-check
```

Preflight обязан подтвердить:

- SMART health `/dev/sdf`;
- UUID `548a00f5-dfd3-47d0-9879-b2a175b5bdb1` и `rw` для `/mnt/ufiles`;
- минимум 100 GiB свободного места;
- активные Docker, system containerd и k3s;
- Docker containerd snapshotter.

При любой ошибке перенос не начинать.

## Dry-run и diff

```bash
sudo ansible-playbook -i ansible/inventory.ini \
  ansible/container-runtime-storage.yml \
  --check --diff \
  -e container_runtime_apply=true
```

Проверить, что diff меняет только containerd root, systemd dependency и Docker
log rotation. Нельзя продолжать, если diff удаляет NVIDIA runtime.

## Backup и миграция

```bash
sudo make containerd-storage-migrate
```

Скрипт автоматически:

1. Повторяет preflight.
2. Запускает OSNOVA backup и `check-data`.
3. Сохраняет inventory и конфигурации в
   `/var/lib/osnova-containerd-migration/<timestamp>`.
4. Останавливает ранее работавшие Docker containers и runtime.
5. Выполняет cold `rsync -aHAXS --numeric-ids` и dry-run verification.
6. Применяет Ansible-конфигурацию и восстанавливает только прежний running set.
7. Проверяет containerd root, Docker, Ollama и Kubernetes node.

Не удалять `/var/lib/containerd` в течение следующих 24 часов.

Если migration завершилась ошибкой только из-за долгого `health: starting`, не
запускать cold copy повторно. После стабилизации контейнера выполнить:

```bash
sudo make containerd-storage-verify
```

По умолчанию verify ждёт health до 10 минут. Это учитывает более медленный cold
start Open WebUI с механического `ufiles`.

## Smoke test

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker system df
containerd config dump | grep '^root = '
docker exec local-ollama ollama list
kubectl get nodes,pods -A
curl -fsS http://127.0.0.1:18080/status.php
df -hT / /mnt/ufiles
```

Дополнительно проверить внешние маршруты Traefik, Nextcloud, обе Open WebUI,
LiteLLM и prombiztech health endpoints.

## Rollback в течение 24 часов

```bash
sudo make containerd-storage-rollback
```

Rollback возвращает исходные конфигурации, запускает прежний
`/var/lib/containerd` и восстанавливает сохранённый running set.

## Finalize

Только после 24 часов стабильной работы и отдельного подтверждения удаления:

```bash
sudo env CONFIRM_DELETE_OLD_CONTAINERD=yes \
  make containerd-storage-finalize
```

Команда повторно проверяет mount, активный containerd root и отсутствие mount
под старым каталогом. После удаления rollback потребует cold rsync с `ufiles`
обратно на SSD.

## Проверка после reboot

```bash
findmnt /mnt/ufiles
systemctl status containerd docker k3s --no-pager
containerd config dump | grep '^root = '
docker ps
kubectl get nodes,pods -A
```

Если `ufiles` отсутствует, containerd и Docker должны fail closed, не создавая
ложный image store в каталоге mountpoint.
