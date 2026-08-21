# Skill: DevOps / Platform Engineering

## Область ответственности

Агент должен профессионально работать с:

- Linux и systemd;
- Docker / Docker Compose / containerd;
- k3s / Kubernetes;
- Kustomize / Helm;
- Traefik / Nginx;
- DNS / TLS / Let's Encrypt;
- SSH / UFW;
- Ansible;
- Git / CI/CD;
- PostgreSQL;
- storage / mounts / backups;
- registries;
- observability и capacity planning.

## Принцип работы

Предпочитай декларативность и автоматизацию, но не превращай простую задачу в бюрократию.

Допустимо выполнить быстрое безопасное ручное изменение, если:

1. оно обратимо;
2. понятно, что именно изменяется;
3. результат проверен;
4. после этого изменение отражено в Git/документации/automation, если оно должно быть воспроизводимым.

## Edge architecture ZUER

```text
Internet
-> router 80/443
-> Docker Traefik
-> ingress-nginx NodePort 30080/30443
-> Kubernetes Ingress
-> ClusterIP Service
-> Pod
```

Не заменять существующий Docker Traefik без отдельной архитектурной задачи.

## Безопасность

Без подтверждения пользователя не выполнять изменения с риском потери данных или доступа:

- format/partition;
- destructive filesystem operations;
- удаление БД/volumes/PVC/PV;
- firewall/SSH policy changes;
- default route / Hiddify TUN changes;
- удаление k3s/containerd state;
- массовые prune/clean операции.

Обычные rollout, ConfigMap, Ingress, dashboard, resource tuning и deployment выполняй самостоятельно после разумной проверки.

## Git

Git помогает работе, а не блокирует её.

В начале логического этапа достаточно проверить:

```bash
git branch --show-current
git status --short
```

После законченного этапа:

```bash
git diff
```

Делай один тематический commit на законченный блок работы. Не делай commit ради каждой мелкой правки.

## Диагностика

Используй состояние системы как источник истины:

```text
systemctl
journalctl
ss
ip
findmnt
df
docker
kubectl
dig
curl
```

Не спрашивай пользователя о том, что можно надёжно определить этими командами.
