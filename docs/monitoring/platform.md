# Monitoring platform ZUER

**Updated:** 2026-08-25

## Фактическое состояние

Единый production monitoring stack на ZUER сейчас не развёрнут.

Доступны только базовые operational signals:

- Kubernetes metrics-server и `kubectl top`;
- readiness/liveness/startup probes у новых Kubernetes приложений;
- Kubernetes events и container logs;
- Docker logs и healthchecks части containers;
- Traefik access/error logs;
- systemd journal;
- backup service/timer results.

Namespace `monitoring` существует, но содержит только автоматически созданный
`kube-root-ca.crt` ConfigMap. В Docker и Kubernetes отсутствуют Prometheus,
Grafana, Loki, Grafana Alloy/Promtail, Alertmanager, kube-state-metrics,
node-exporter, cAdvisor и Blackbox Exporter.

## PromBizTech Analytics Platform

Код будущего analytics/observability контура находится в worktree:

```text
/run/media/nsadmin/godny_soft/soft/prombiztech-analytics-platform
branch: agent/v2-2-2-analytics-platform
```

В нём подготовлены Prometheus, Grafana, Loki, Alloy, dashboards, alert rules,
analytics ingestion и tests. Этот worktree не является live monitoring
platform: branch расходится с integration, имеет dirty files и не развёрнут.

## Целевой подход

Не создавать второй parallel stack. После merge/test использовать один
канонический observability contour и подключить к нему:

1. ZUER node/system metrics.
2. Kubernetes state, requests/limits, restarts, PVC и ingress.
3. Docker Traefik и остающиеся Compose services.
4. PromBiz.Tech, Anaconda, Nextcloud, AI/LLM, затем Kolos.
5. Backup, TLS expiry и blackbox availability alerts.

Grafana не публиковать анонимно; Prometheus/Loki/Alloy оставлять internal.
Stateful monitoring data требует retention, backup scope и resource limits.

## Блокеры

- analytics branch: 7 unique commits, integration branch: 14 unique commits;
- оба PromBizTech worktree содержат незакоммиченные изменения;
- нет подтверждённого sizing/retention;
- нет выделенного ingress/access policy;
- нет deployment smoke и backup/restore evidence.

## Проверка

```bash
kubectl -n monitoring get all,configmap,secret,pvc
docker ps --format '{{.Names}} {{.Image}}' | grep -Ei \
  'prometheus|grafana|loki|alloy|alertmanager|exporter|cadvisor'
```

Полный audit: `docs/reports/2026-08-25-zuer-projects-runtime-git-audit.md`.
