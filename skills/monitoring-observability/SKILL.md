# Skill: Monitoring / Observability

## Роль

Работай как Senior Observability / SRE Engineer. Цель мониторинга — быстро понимать состояние системы, диагностировать причины деградации и принимать эксплуатационные решения.

Отдельная monitoring-платформа проекта называется:

```text
PromBizTech Analytics Platform
```

При первой monitoring-задаче найди её реальный путь на ZUER, изучи существующую архитектуру и зафиксируй в `docs/monitoring/platform.md`.

Не создавай второй параллельный Prometheus/Grafana stack, если существующий можно расширить.

## Экспертиза

Уверенно работай с:

- Prometheus;
- Grafana;
- Loki;
- Grafana Alloy / Promtail;
- Node Exporter;
- cAdvisor;
- kube-state-metrics;
- metrics-server;
- PostgreSQL Exporter;
- Blackbox Exporter;
- NVIDIA DCGM Exporter / GPU metrics;
- OpenTelemetry;
- Alertmanager.

Используй SRE-подходы:

- Golden Signals;
- RED;
- USE;
- SLI/SLO/SLA;
- error budget;
- recording rules;
- cardinality control;
- capacity planning;
- alert fatigue prevention.

## Перед добавлением метрики

Определи:

1. зачем метрика нужна;
2. какое решение по ней можно принять;
3. риск cardinality;
4. ориентировочное число time series;
5. retention;
6. нужна ли recording rule.

Не собирай метрики только потому, что это возможно.

## Dashboard architecture

Предпочитай структуру:

```text
Overview -> drill-down -> detailed diagnostics
```

### ZUER Overview

Минимум:

- CPU usage/load;
- RAM/cache/free;
- swap;
- filesystem usage;
- disk latency/throughput/IOPS;
- network traffic/errors;
- temperatures;
- GPU utilization/VRAM/temperature;
- Docker containers;
- Kubernetes pods/restarts;
- cluster requests/limits;
- storage usage.

### Kubernetes Overview

- node conditions;
- namespaces;
- Running/Pending/Failed pods;
- restarts;
- CPU/RAM usage;
- requests/limits;
- Deployments/StatefulSets;
- PV/PVC;
- network;
- Ingress traffic/errors.

### Application dashboards

Для Kolos и Anaconda:

- availability;
- request rate;
- latency;
- HTTP 2xx/4xx/5xx;
- CPU/RAM;
- restarts;
- DB connections/latency/size;
- dependency health.

### PostgreSQL

- connections;
- active queries;
- transactions;
- commits/rollbacks;
- locks/deadlocks;
- slow queries;
- cache hit ratio;
- DB size;
- WAL;
- IO.

### Edge / Traefik

- requests/sec;
- latency;
- 2xx/3xx/4xx/5xx;
- backend/routing/TLS errors;
- certificate expiry.

## Grafana quality standard

Используй:

- variables;
- repeat panels только когда они реально уменьшают дублирование;
- dashboard links;
- annotations;
- row grouping;
- корректные units;
- понятные thresholds;
- единый naming;
- небольшое число действительно полезных панелей.

Не создавай перегруженные dashboards ради визуального эффекта.

## Alerts

Alert должен означать, что требуется действие человека.

Классы:

```text
INFO
WARNING
CRITICAL
```

Кандидаты CRITICAL:

- node unavailable;
- app unavailable;
- DB unavailable;
- filesystem/PVC almost full;
- excessive pod restarts;
- ingress unavailable;
- backup failed;
- TLS certificate near expiry;
- GPU overheating.

После изменения observability обязательно проверить, что metrics реально поступают и панели/alerts используют существующие series, а не пустые выражения.
