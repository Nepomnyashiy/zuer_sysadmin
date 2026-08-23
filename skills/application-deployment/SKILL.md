# Skill: Application Deployment Standard

## Цель

Стандартизировать публикацию приложений OSNOVA/GodnySoft на `*.godny.tech` через существующую платформу ZUER.

## Базовый pipeline

```text
source
-> Docker build
-> local registry 127.0.0.1:30500
-> Kubernetes Deployment/StatefulSet
-> ClusterIP Service
-> Ingress
-> ingress-nginx
-> Docker Traefik
-> public HTTPS on *.godny.tech
```

## Стандарт приложения

Для каждого приложения должны быть определены:

- исходный каталог;
- build context и Dockerfile;
- namespace;
- image names/tags;
- ConfigMap;
- Secret;
- Deployments/StatefulSets;
- Services;
- Ingress hosts;
- probes;
- resource requests/limits;
- persistent volumes;
- backup/restore для stateful data;
- smoke checks;
- operational README.

## Доменные правила

Публичные сервисы размещаются на поддоменах `godny.tech`.

Текущие целевые адреса:

### Kolos

- `https://agro.godny.tech`
- `https://api.agro.godny.tech`

Не переименовывать Kolos в `kolos.godny.tech` без отдельного решения.

### Anaconda

- `https://anaconda.godny.tech`

Текущий Anaconda Site — статический React/Vite frontend из
`/run/media/nsadmin/godny_soft/site/anaconda_site`. Не создавать для него API,
PostgreSQL, Redis или Secret без появления реальной server-side зависимости.
Не передавать API keys через Vite build args/env: они попадут в публичный
browser bundle.

## Сборка и публикация

Используй существующие Make targets и `scripts/k8s/build-app-images.sh`.

```bash
make app-build APP=<app>
make app-push APP=<app>
make app-apply APP=<app>
```

Для одного rollout используй один immutable tag во всех командах. `app-push`
должен публиковать уже проверенный local image, а не пересобирать его:

```bash
make app-build APP=<app> IMAGE_TAG=git-<source-sha>
make app-push APP=<app> IMAGE_TAG=git-<source-sha>
```

После push проверь tag и OCI digest через registry API. В production manifests
предпочитай `tag@sha256:digest`.

Secret создавай с allowlist необходимых keys, если source `.env` содержит и
секретные, и обычные настройки:

```bash
./scripts/k8s/create-secret-from-env.sh \
  <namespace> <secret-name> /path/to/.env KEY_ONE KEY_TWO
```

Не импортируй весь `.env` в Secret без необходимости.

При первом rollout или существенном изменении:

```bash
make app-dry-run APP=<app>
make app-diff APP=<app>
```

## Проверка

Сначала внутри Kubernetes, затем edge, затем public HTTPS.

```bash
kubectl -n <ns> get pods,svc,ingress,pvc
kubectl -n <ns> rollout status deployment/<name>
```

Проверка ingress без внешнего DNS:

```bash
curl -H 'Host: <host>' http://127.0.0.1:30080/
```

Публичная проверка с обходом Hiddify/proxy:

```bash
curl --noproxy '*' -I https://<host>
```

## Image tags

Для production-adjacent rollout предпочтительны трассируемые immutable tags, например:

```text
git-<short-sha>
20260821-1030
```

Не полагайся постоянно на mutable `local`/`latest`, если требуется воспроизводимый rollback.

## Definition of Done для приложения

- image собран и доступен registry;
- Secret/ConfigMap корректны;
- required Pods Ready;
- rollout завершён;
- stateful data сохранены;
- PVC Bound;
- Service отвечает;
- Ingress маршрутизирует;
- Traefik маршрутизирует;
- public HTTPS отвечает ожидаемо;
- приложение не создаёт критическую нагрузку на ZUER;
- мониторинг и базовые health signals доступны;
- документация и `tasks/CURRENT.md` обновлены.
