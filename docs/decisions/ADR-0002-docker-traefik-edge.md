# ADR-0002: Docker Traefik как временный edge proxy перед Kubernetes

Дата: 2026-07-10
Статус: accepted

## Контекст

На сервере уже работает Docker Traefik, который публикует `cloud.godny.tech`,
`traefik.godny.tech` и AI routes. Его резкая замена может сломать публичные
сервисы.

## Решение

Оставить Docker Traefik внешней точкой входа на `80/443`. Kubernetes ingress
публиковать внутри хоста через `ingress-nginx` NodePort `30080/30443`.
Маршруты переносить по одному host.

## Последствия

- Можно откатить конкретный host обратно на Docker backend.
- Не нужно сразу менять DNS, UFW и router forwarding.
- На время миграции есть два reverse proxy слоя.

## Альтернативы

- Сразу заменить Docker Traefik на Kubernetes Ingress: быстрее, но рискованно.
- Использовать NodePort напрямую: хуже для TLS и route governance.
- Использовать LoadBalancer/MetalLB: возможно позже, но на single-node не
  требуется для первого этапа.

## Rollback

Вернуть route в Docker Traefik на старый Docker service и убрать Kubernetes
route из dynamic config. Kubernetes workloads при этом можно оставить для
диагностики.

