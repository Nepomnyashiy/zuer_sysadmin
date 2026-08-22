# Ход-отчёт: Anaconda Kubernetes rollout

Дата: 2026-08-22

## Цель

Выполнить первый безопасный rollout Anaconda после secrets hygiene и проверить
цепочку Pod -> Service -> Kubernetes Ingress без изменения Docker Traefik.

## Что сделано

- Повторены Vault Secret dry-run, server-side app dry-run и live diff.
- `anaconda-secret` создан из encrypted Vault с allowlist из четырёх keys.
- Созданы API/web Deployments, PostgreSQL StatefulSet, ClusterIP Services,
  Ingress и retained PVC 20 GiB.
- После history rewrite images перевыпущены с трассируемым tag `git-477accd`.
- Убрано раскрытие IMAP user из API log и `/api/email/info`; source commit
  `477accd` опубликован в `agent/anaconda-k8s-readiness`.
- API получил non-root initContainer с `pg_isready` для cold start PostgreSQL.
- Backup root отделён от root-owned system backups:
  `/mnt/ufiles/k8s-backups/postgres`.
- Создан baseline PostgreSQL dump mode `600`.

## Проверки

- API, web, PostgreSQL: `1/1 Ready`, restart count `0` после финального rollout.
- PVC `data-anaconda-postgres-0`: `Bound`; PV reclaim policy `Retain`.
- Source Python syntax, Kustomize render и server-side dry-run: OK.
- Live diff перед каждым apply содержал только ожидаемые изменения.
- Repository smoke: rollout, PVC, `/live`, `/ready`, web `/healthz` — OK.
- `/api/email/info` возвращает только boolean `imap_user_configured`.
- Baseline dump: 13,134 bytes, mode `600`; containerized
  `pg_restore --list` — OK. Restore не выполнялся.
- Node `Ready`, MemoryPressure/DiskPressure `False`; Pods используют примерно
  13m CPU и 99 MiB RAM суммарно на момент проверки.

## Найденные проблемы

- Первый API Pod рестартовал четыре раза, пока PostgreSQL инициализировался.
- Первый вариант initContainer не запускался: official Postgres image не
  объявляет non-root USER для kubelet. Исправлено явным Alpine PostgreSQL UID
  `70`; ошибочный ReplicaSet удалён Deployment controller.
- API печатал IMAP user в startup log и отдавал его diagnostic endpoint.
- Старый backup root находился внутри root-owned `/mnt/ufiles/backups`.
- Host `pg_restore` отсутствует; проверка dump выполняется pinned PostgreSQL
  tooling внутри Pod через stdin.

## Результат

Внутренний Kubernetes rollout Anaconda завершён. Public HTTPS ещё не включён:
в Docker Traefik отсутствуют host rules для Anaconda.

## Следующий шаг

Подготовить и проверить отдельные Traefik routes для
`anaconda.godny.tech`/`api.anaconda.godny.tech` на
`http://192.168.0.101:30080`, затем выполнить public HTTPS smoke и проверить,
что существующие routes не изменились.

## Rollback

- Stateless workloads: вернуть предыдущие image tag/digest и применить
  manifests.
- PostgreSQL PVC/PV не удалять; policy `Retain` сохраняет данные.
- Secret можно обновить повторным Vault-backed apply; values не фиксируются в
  Git.
- Edge route на этом этапе не применялся, поэтому edge rollback не требуется.
