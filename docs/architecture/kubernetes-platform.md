# Kubernetes-платформа ZUER

Дата: 2026-07-10

## Цель

Построить локальную Kubernetes-платформу на сервере `ZUER` для постепенного
переноса приложений из Docker Compose:

- `black_mamba`;
- `anaconda`;
- `kolos`;
- `barber`;
- будущие приложения по единому шаблону.

Платформа должна быть декларативной, воспроизводимой и безопасной для текущих
публичных сервисов `godny.tech`.

## Базовая схема

```text
Internet
  -> godny.tech / *.godny.tech
  -> router 80/443
  -> ZUER Docker Traefik
  -> existing Docker services
  -> Kubernetes ingress-nginx NodePort 30080/30443
  -> Kubernetes Services
  -> Pods / PVC
```

Существующий Docker Traefik остается внешней точкой входа на первом этапе.
Kubernetes получает внутренний ingress через NodePort. Это позволяет переносить
hosts по одному и откатывать маршрут обратно на Docker Compose.

## Слои платформы

- Host baseline: Ubuntu 26.04, Docker, UFW, mounts, backup.
- Kubernetes runtime: `k3s` single-node.
- Ingress: `ingress-nginx` внутри Kubernetes, Docker Traefik как edge proxy.
- Storage: `local-path-provisioner` на `/mnt/ufiles/k8s/local-path`.
- Registry: локальный registry `127.0.0.1:30500` для первых релизов.
- Secrets: локальные `.env` и генерация Kubernetes Secret без plain YAML в Git.
- Observability: сначала health/logs/resources, затем Prometheus/Grafana/Loki.
- Backup: PostgreSQL dumps и архивы PVC/host-path данных.

## Namespace model

```text
ingress
monitoring
databases
ai-platform
anaconda
kolos
barber
```

Каждое приложение получает отдельный namespace. Общие компоненты живут в
платформенных namespace. Это упрощает лимиты, network policies, backup и
rollout.

## Миграционная стратегия

1. Подготовить tooling и preflight без изменения runtime.
2. Установить k3s и базовые компоненты через Ansible/Makefile.
3. Перенести `barber` как простой web/API сервис.
4. Перенести `anaconda` с PostgreSQL и внешними интеграциями.
5. Перенести `kolos` после backup PostgreSQL/uploads.
6. Перенести `black_mamba` по частям; `ollama` только после GPU preflight.

## Эксплуатационный стандарт приложения

Каждое приложение должно иметь:

- namespace;
- ConfigMap для несекретной конфигурации;
- Secret, созданный скриптом из локального `.env`;
- Deployment/StatefulSet;
- Service только `ClusterIP`, если сервис не должен быть публичным;
- Ingress только для HTTP/HTTPS входа;
- readiness/liveness probes;
- resource requests/limits;
- PVC для данных;
- backup/restore runbook;
- smoke test.

## Риски

- Текущий Docker Traefik обслуживает production-adjacent сервисы, его нельзя
  заменять одномоментно.
- `/run/media/nsadmin/godny_soft` в агентской среде может отображаться `ro`;
  перед применением на хосте нужен реальный `findmnt`.
- `nvidia-smi` в текущей среде не видит NVIDIA driver; перенос `ollama` требует
  отдельной проверки host GPU runtime и containerd integration.
- PostgreSQL и Redis нельзя публиковать наружу через NodePort/LoadBalancer.
- k3s с default flannel не даёт полноценного NetworkPolicy enforcement.
  Добавленные policies фиксируют целевое намерение, но для реальной изоляции
  нужно отдельное решение по CNI: Cilium или Calico.
