# App template

## Что заменить

- `APP_NAME`
- `APP_NAMESPACE`
- image names
- ports
- health endpoints
- PVC sizes
- ingress host

## Стандарт

- Не публиковать базы данных наружу.
- Все HTTP-сервисы публиковать через Ingress.
- Secrets создавать скриптом `scripts/k8s/create-secret-from-env.sh`.
- Перед apply запускать `kubectl apply --dry-run=server -k apps/<app>/k8s`.

