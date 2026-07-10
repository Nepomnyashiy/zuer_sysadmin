# ADR-0001: k3s как локальная Kubernetes-платформа

Дата: 2026-07-10
Статус: accepted

## Контекст

Сервер `ZUER` является single-node хостом для сервисов `godny.tech`.
Нужна Kubernetes-платформа, но без сложной multi-node эксплуатации на первом
этапе.

## Решение

Использовать `k3s` как локальный single-node Kubernetes runtime. Установку
делать через Ansible/скрипты с preflight и rollback-планом.

## Последствия

- Быстрый старт Kubernetes без отдельного control plane.
- Меньше moving parts для домашнего/production-adjacent сервера.
- Stateful-нагрузки требуют аккуратного backup, потому что узел один.

## Альтернативы

- `kubeadm`: ближе к production multi-node, но тяжелее для первого шага.
- `kind`/`minikube`: хорошо для лаборатории, но не целевая платформа сервера.
- Managed Kubernetes: лучше для production, но не решает локальную платформу.

## Rollback

До миграции hosts приложения остаются в Docker Compose. При проблеме k3s можно
остановить и удалить отдельно, не трогая Docker Traefik и volumes приложений.

