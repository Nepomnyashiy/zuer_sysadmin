# Anaconda Site on Kubernetes

## Source

```text
/run/media/nsadmin/godny_soft/site/anaconda_site
repository: Nepomnyashiy/anaconda_site
branch: agent/anaconda-site-k8s
```

Это статический React/Vite-сайт. Ему не нужны API Deployment, PostgreSQL,
Redis, ConfigMap или Kubernetes Secret.

## Build and deploy

Если основной checkout не переключён на source-ветку из-за сохранённого dirty
state, укажи подготовленный worktree через `ANACONDA_SOURCE_ROOT`:

```bash
ANACONDA_SOURCE_ROOT=/tmp/anaconda-site-k8s-worktree \
  make app-build APP=anaconda IMAGE_TAG=git-22a7f3f
ANACONDA_SOURCE_ROOT=/tmp/anaconda-site-k8s-worktree \
  make app-push APP=anaconda IMAGE_TAG=git-22a7f3f

make app-dry-run APP=anaconda
make app-diff APP=anaconda
make app-apply APP=anaconda
./apps/anaconda/scripts/smoke.sh
```

Production image — multi-stage build с unprivileged Nginx на `8080`. Image
фиксируется в Kustomize по immutable tag и OCI digest.

## Edge

После Kubernetes smoke:

```bash
make anaconda-edge-check
make anaconda-edge-apply
```

Edge публикует только `anaconda.godny.tech`. Host
`api.anaconda.godny.tech` для статического сайта не используется.

## Legacy MVP resources

Ошибочно развёрнутые `anaconda_mvp` API/PostgreSQL resources не входят в новый
desired state. Их нельзя удалять автоматически: PVC/PV и Secret сохраняются до
отдельного cleanup с явным подтверждением. После готовности сайта legacy
controllers можно масштабировать в `0`, не удаляя retained data.

## Secrets

Статический frontend не принимает API keys: значения Vite попадают в публичный
JavaScript bundle. В source history обнаружены старые OpenRouter/Gemini keys;
их необходимо отозвать и выполнить отдельный подтверждённый history cleanup.
