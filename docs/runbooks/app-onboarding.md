# Runbook: добавление нового приложения в Kubernetes

Дата: 2026-07-10

## Что делаем

Добавляем новое приложение по единому шаблону `apps/_template`.

## Зачем

Одинаковая структура снижает стоимость сопровождения: инженеру сразу понятно,
где namespace, config, secrets, service, ingress, probes, resources и backup.

## Шаги

1. Создать каталог:

```bash
cp -R apps/_template apps/<app-name>
```

2. Заменить placeholders:

```text
APP_NAME
APP_NAMESPACE
image
ports
health endpoints
ingress host
PVC sizes
```

3. Разделить конфигурацию:

- ConfigMap: hostnames, ports, feature flags, public URLs.
- Secret: passwords, tokens, API keys, JWT secrets.

4. Создать secret из локального env:

```bash
./scripts/k8s/create-secret-from-env.sh <namespace> <app>-secret /path/to/.env
```

5. Проверить manifests:

```bash
kubectl apply --dry-run=server -k apps/<app-name>/k8s
kubectl diff -k apps/<app-name>/k8s
```

6. Применить:

```bash
kubectl apply -k apps/<app-name>/k8s
```

## Минимальные требования

- Не публиковать БД наружу.
- Для stateless сервисов использовать `Deployment`.
- Для БД использовать `StatefulSet` и PVC.
- У каждого контейнера должны быть probes и resources.
- Для stateful-сервиса должен быть backup и restore-проверка.

