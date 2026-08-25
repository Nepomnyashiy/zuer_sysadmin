# Skill: System Startup Audit

## Назначение

Быстро восстановить реальное состояние ZUER в начале новой рабочей сессии и определить, можно ли безопасно продолжать инфраструктурную работу.

Полный аудит выполняется один раз на сессию или после существенных изменений. Не повторяй его механически перед каждой командой.

## Быстрый delta-check

Если `docs/state/latest-audit.md` свежий и сервер не перезагружался:

```bash
uptime
free -h
df -h
docker ps
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

## Полный аудит

```bash
hostname
date -Is
uptime
uname -a
cat /etc/os-release
lscpu
free -h
swapon --show
df -h
findmnt
ip -br addr
ip route
ss -lntup
docker ps
docker system df
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces
kubectl get pods -A -o wide
kubectl get deploy,statefulset,daemonset -A
kubectl get svc,ingress -A
kubectl get pv,pvc -A
kubectl get storageclass
kubectl get events -A --sort-by=.lastTimestamp | tail -100
kubectl top nodes 2>/dev/null || true
kubectl top pods -A 2>/dev/null || true
nvidia-smi 2>/dev/null || true
systemctl --failed --no-pager
```

Дополнительно используй существующие команды проекта:

```bash
make k8s-preflight
make k8s-status
```

## Что оценить

- CPU/load и доступный запас CPU.
- RAM/swap и риск memory pressure.
- GPU/VRAM, если задача использует GPU.
- свободное место на `/`, `/mnt/ufiles`, `godny_soft` и Kubernetes storage.
- ro/rw состояние важных mountpoints.
- состояние Docker и k3s.
- Node Conditions.
- Pending/Failed/CrashLoopBackOff pods.
- рестарты pods.
- состояние ingress-nginx, registry, PV/PVC.
- критические systemd failures.
- занятые edge ports 80/443/30080/30443/30500.

Для NodePort не считать отсутствие userspace listener в `ss` ошибкой:
kube-proxy может обслуживать порт через iptables/nftables. Проверяй
функционально:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:30080/
curl -k -sS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:30443/
curl -sS -i http://127.0.0.1:30500/v2/
```

## Результат

Обнови `docs/state/latest-audit.md` без секретов.

Краткий отчёт агенту/пользователю:

```text
ZUER SYSTEM STATUS
Host:
Uptime:
CPU:
RAM:
Swap:
GPU:
Storage:
Docker:
k3s:
Kubernetes:
Ingress:
Registry:
PVC/PV:
Critical errors:
Warnings:
Available resources:
STATUS: OK | DEGRADED | CRITICAL
```

После отчёта продолжай активную задачу, если нет блокирующего риска.
