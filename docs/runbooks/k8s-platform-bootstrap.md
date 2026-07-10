# Runbook: bootstrap Kubernetes-платформы

Дата: 2026-07-10

## Что делаем

Подготавливаем `ZUER` к запуску single-node Kubernetes на `k3s` и переносим
приложения по одному, не ломая текущий Docker/Traefik слой.

## Зачем

Compose остается источником информации и rollback-средой, но целевая платформа
эксплуатации - Kubernetes. Такой подход дает GitOps-ready manifests, namespace
изоляцию, health probes, resource limits и нормальную модель backup/restore.

## Предварительные проверки

```bash
make k8s-preflight
```

Критично проверить:

- `/mnt/ufiles` смонтирован `rw`;
- `80/443` уже заняты Docker Traefik и не должны быть перехвачены;
- `kubectl`, `helm`, `kustomize`, `k3s` могут быть установлены;
- GPU виден через `nvidia-smi` до переноса `ollama`.

## Установка tooling и k3s

Сначала dry-run/check:

```bash
make k8s-install-check
```

Применение делать только после просмотра diff/check output:

```bash
make k8s-install
```

## Проверка платформы

```bash
make k8s-status
kubectl get nodes -o wide
kubectl get pods,svc,ingress,pvc -A
```

NetworkPolicy manifests в репозитории фиксируют целевую модель доступа, но
default k3s/flannel может их не enforcing. До подключения Cilium/Calico не
считать network policies полноценной защитой.

## Проверка manifests

```bash
make k8s-build-local
make k8s-dry-run-local
```

Если кластер уже установлен:

```bash
make k8s-diff-local
```

## Порядок миграции приложений

1. `barber` - самый простой API/frontend/PostgreSQL/Redis.
2. `anaconda` - FastAPI/Vue/PostgreSQL и внешние webhook/IMAP/SMTP.
3. `kolos` - production-like Strapi/Next.js/PostgreSQL/uploads.
4. `black_mamba` - AI stack; Ollama переносить только после GPU preflight.

## Rollback

- Не удалять Docker Compose stacks до проверки Kubernetes версии.
- Не удалять PVC/PV/volumes без отдельного подтверждения.
- Для HTTP rollback вернуть Docker Traefik route на старый backend.
- Для Deployment rollback использовать:

```bash
kubectl rollout undo deployment/<name> -n <namespace>
```

## Что важно запомнить

Kubernetes не заменяет backup и не делает single-node отказоустойчивым. Он
делает запуск приложений декларативным и управляемым, но данные нужно отдельно
бэкапить и проверять restore.
