# Ход-отчёт: platform и DNS validation

Дата: 2026-08-21

## Цель

Подтвердить рабочую цепочку Docker Traefik -> ingress-nginx NodePort, исключить
конфликты live routes и проверить DNS перед deployment приложений.

## Что сделано

- Проверены live host rules и upstreams Traefik через запущенный контейнер.
- Проверена доступность ingress-nginx по localhost и LAN на `30080/30443`.
- Проверен запрос из Traefik container к `192.168.0.101:30080`.
- Проверены существующие public endpoints Nextcloud и Traefik dashboard.
- Проверены A/AAAA/CNAME четырёх целевых hosts через system resolver и
  `1.1.1.1`.

## Изменённые файлы

- `tasks/CURRENT.md`.
- `docs/state/latest-audit.md`.
- `docs/reports/2026-08-21-platform-dns-validation.md`.

## Выполненные команды

Использовались read-only команды `docker inspect`, `docker exec ... grep`,
`docker logs`, `curl`, `kubectl get/describe` и `dig`.

## Проверки

- ingress-nginx: `1/1 Ready`, endpoints существуют.
- `30080/30443`: возвращают ожидаемый `404` без app Ingress.
- Traefik container -> `192.168.0.101:30080`: соединение успешно.
- Registry `30500`: HTTP 200; `osnova-local-retain`: существует, Retain.
- Live Traefik routes не содержат target Kolos/Anaconda hosts.
- Все target A records: `85.172.104.173` у двух resolvers.
- Existing public checks: Nextcloud `302 /login`, dashboard `401`.

## Результат

Phase 3 и Phase 4 завершены. Platform edge готов к подключению app routes после
успешного rollout приложений.

## Найденные проблемы

Prepared example с `127.0.0.1:30080` не подходит для Docker Traefik без host
networking. Рабочий проверенный upstream на текущем хосте —
`http://192.168.0.101:30080`.

## Риски

- LAN IP должен оставаться стабильным или быть заменён на явно настроенный
  Docker host gateway.
- Traefik routes нельзя активировать до Pod/Service/Ingress smoke tests, иначе
  public host получит 404/502.
- Переключение public route должно выполняться по одному host с сохранённой
  копией live dynamic config.

## Что осталось

- Выполнить pre-deployment review Anaconda source и manifests.
- Создать Secret без вывода значений только после проверки требуемых keys.
- Build/push/dry-run/diff/apply/rollout Anaconda.

## Следующий шаг

Phase 5: read-only audit Anaconda Dockerfiles, Compose, env key names и
Kubernetes manifests; затем сформировать точный deployment plan.

## Rollback

Runtime и DNS не изменялись. Документационные изменения отменяются revert
тематического Git-коммита.
