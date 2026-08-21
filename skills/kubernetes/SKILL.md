# Skill: Kubernetes Operations

## Контекст ZUER

- Runtime: `k3s`.
- Edge proxy: существующий Docker Traefik.
- Ingress внутри Kubernetes: `ingress-nginx`.
- NodePort ingress: `30080/30443`.
- Local registry: `127.0.0.1:30500`.
- StorageClass: `osnova-local-retain`.
- Host ports `80/443` Kubernetes не занимает.

## Базовый принцип

```text
inspect -> change -> apply -> rollout -> verify
```

Проверки должны соответствовать риску, а не выполняться механически.

### Low risk

ConfigMap, dashboard, очевидный Ingress fix, image tag, resource tuning:

```text
check -> change -> apply -> verify
```

### Medium risk

Новый deployment, Service, Ingress, Helm chart, PVC mount:

```text
check -> change -> dry-run/diff when useful -> apply -> verify
```

### High risk

PVC/PV deletion, namespace deletion, destructive DB/storage operation:

```text
audit -> backup -> rollback plan -> user confirmation -> execute -> verify
```

## Стандарт приложения

Каждое production-adjacent приложение должно иметь по необходимости:

- Namespace;
- ConfigMap;
- Secret;
- Deployment или StatefulSet;
- ClusterIP Service;
- Ingress для публичного HTTP/HTTPS;
- readinessProbe;
- livenessProbe;
- startupProbe для долгого старта;
- resource requests/limits;
- PVC для persistent data;
- backup/restore procedure;
- smoke test;
- README/runbook.

PostgreSQL наружу не публиковать.

## Deployment workflow

Используй существующий Makefile:

```bash
make app-build APP=<app>
make app-push APP=<app>
make app-dry-run APP=<app>
make app-diff APP=<app>
make app-apply APP=<app>
```

Для небольших очевидных изменений `dry-run` и `diff` можно не дублировать, если состояние уже известно и rollback простой.

## Проверка после apply

```bash
kubectl -n <namespace> get pods,svc,ingress,pvc
kubectl -n <namespace> rollout status deployment/<deployment>
kubectl -n <namespace> get events --sort-by=.lastTimestamp | tail -50
kubectl -n <namespace> logs <pod> --tail=100
```

Проверять цепочку по слоям:

```text
Pod -> Service -> Ingress -> ingress-nginx -> Docker Traefik -> public HTTPS
```

## Stateful workloads

Перед переносом PostgreSQL или другого stateful workload выяснить:

- где текущие production data;
- размер данных;
- backup format;
- restore procedure;
- допустимый downtime;
- StorageClass;
- reclaim policy;
- физическое расположение volume;
- rollback path.

Не подменять рабочую базу пустой БД.

## Запрещено без отдельного подтверждения

- `kubectl delete namespace`;
- удаление PVC/PV;
- `kubectl replace --force` для stateful workloads;
- удаление k3s;
- очистка containerd;
- destructive storage operations.
