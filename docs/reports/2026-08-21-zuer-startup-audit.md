# Ход-отчёт: live startup audit ZUER

Дата: 2026-08-21

## Цель

Сверить `tasks/CURRENT.md` с фактическим состоянием ZUER и определить, можно ли
безопасно переходить к platform validation и deployment Kolos/Anaconda.

## Что сделано

- Выполнен полный startup audit по `skills/system-startup/SKILL.md`.
- Проверены host resources, storage/mounts, сеть, Docker, GPU и systemd.
- Проверены k3s node, workloads, ingress-nginx, registry, metrics и storage.
- Функционально проверены NodePort `30080/30443` и registry `30500`.
- Разобраны backup errors из текущего boot; подтверждён последующий успешный
  snapshot и активные timers.

## Изменённые файлы

- `docs/state/latest-audit.md`.
- `tasks/CURRENT.md`.
- `docs/reports/2026-08-21-zuer-startup-audit.md`.

## Выполненные команды

Использовались read-only команды `hostname`, `uptime`, `lscpu`, `free`, `df`,
`findmnt`, `ip`, `ss`, `docker`, `nvidia-smi`, `systemctl`, `journalctl`,
`kubectl`, `curl`, а также `make k8s-preflight` и `make k8s-status`.

## Проверки

- Node `zuer` — `Ready`, pressure conditions отсутствуют.
- 5/5 infrastructure Pods — `Running/Ready`.
- ingress-nginx NodePort отвечает на `30080/30443`.
- registry `/v2/` отвечает HTTP 200.
- `osnova-local-retain` и registry PVC/PV существуют; PV расположен на
  `/mnt/ufiles`.
- Важные mounts — `rw`; активных failed systemd units нет.
- Последний backup — `Result=success`, exit code 0.

## Результат

Статус ZUER: `OK`. Capacity предварительно достаточен для Kolos и Anaconda.
Можно продолжать Phase 3 без runtime changes на этом этапе.

## Найденные проблемы

- Root filesystem заполнен на 67%.
- Docker показывает около 23.93 GB reclaimable images; cleanup не выполнялся.
- `k8s-preflight` ошибочно предупреждает, что NodePort не слушает, поскольку
  использует `ss`; функциональные curl-проверки успешны.
- В начале 2026-08-20 backup дважды завершался ошибкой, но последующие запуски
  и последний timer-run успешны.

## Риски

- Single-node k3s не обеспечивает HA.
- Stateful приложения нельзя переносить до проверки production data,
  backup/restore и rollback.
- Docker image cleanup без проверки тегов может удалить rollback-образы.

## Что осталось

- Проверить Traefik -> ingress-nginx routing и конфликты public routes.
- Проверить DNS четырёх целевых доменов.
- Выполнить отдельный pre-deployment review Anaconda и Kolos.

## Следующий шаг

Phase 3 platform validation, затем Phase 4 DNS.

## Rollback

Runtime не изменялся; rollback не требуется. Документационные изменения можно
отменить обычным revert тематического Git-коммита.
