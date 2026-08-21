# Skill: Incident Diagnostics

## Цель

Быстро локализовать причину деградации, не вносить хаотичные изменения и не маскировать симптом перезапуском всего подряд.

## Базовый цикл

```text
symptom -> scope -> recent changes -> logs/events/metrics -> hypothesis -> smallest test -> fix -> verify -> document
```

## Сначала определить слой проблемы

- host/Linux;
- storage;
- network/DNS;
- Docker/containerd;
- k3s control plane;
- Kubernetes scheduling;
- Pod/container;
- Service/Ingress;
- Traefik/TLS;
- database;
- application;
- external dependency.

## Быстрая диагностика Kubernetes

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -100
kubectl describe pod -n <ns> <pod>
kubectl logs -n <ns> <pod> --tail=200
kubectl logs -n <ns> <pod> --previous --tail=200
kubectl get svc,ingress,endpoints -A
```

## Host diagnostics

```bash
uptime
free -h
df -h
findmnt
systemctl --failed --no-pager
journalctl -p warning -n 200 --no-pager
ss -lntup
ip -br addr
ip route
```

## Правила

- не начинай с restart всей платформы;
- сначала сохрани evidence;
- не удаляй CrashLoopBackOff pod без чтения logs/events;
- не очищай volumes/cache/containerd как универсальное лечение;
- не меняй сразу несколько слоёв одновременно;
- после исправления проверь исходный пользовательский симптом.

Если найден повторяемый сценарий, обнови соответствующий skill/runbook.
