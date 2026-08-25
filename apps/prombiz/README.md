# PromBiz.Tech on Kubernetes

Source: /run/media/nsadmin/godny_soft/soft/anaconda_web

Repository: Nepomnyashiy/anaconda_web, branch agent/prombiz-rebrand.

Это статический Astro-сайт. Backend, database, persistent volumes и Kubernetes
Secret не требуются.

## Build and deploy

Используй один immutable tag на всех шагах:

    make app-build APP=prombiz IMAGE_TAG=git-3bdc760
    make app-push APP=prombiz IMAGE_TAG=git-3bdc760
    make app-dry-run APP=prombiz
    make app-diff APP=prombiz
    make app-apply APP=prombiz
    ./apps/prombiz/scripts/smoke.sh

Deployed manifest pins the registry digest:

    sha256:dc173606762e62fb167a549dadde293a491f7c473411f1d8db057495a5a27dd1

## Edge cutover

После успешного Kubernetes smoke:

    make prombiz-edge-check
    make prombiz-edge-apply

Edge route сохраняет Docker Traefik и меняет upstream с legacy Compose service
на http://192.168.0.101:30080. www.prombiz.tech получает permanent redirect
на https://prombiz.tech.

## Rollback

До cutover legacy runtime остаётся запущен:

    container: prombiztech-production-web
    compose: /tmp/prombiztech-rollback-a12/deploy/production/compose.yaml
    image: prombiztech-web@sha256:a9832f9189a091c9c374605d99e06f2f0f9f389353062afbf9f1a5d5a282736a

Edge playbook сохраняет исходный route:

    /srv/proxy/traefik/dynamic/prombiz-production.pre-k8s.yml.bak

Legacy production runtime заморожен после успешного cutover:

    source: /run/media/nsadmin/godny_soft/soft/prombiztech
    container: prombiztech-production-web
    state: stopped, restart=no (FROZEN)
    compose: /tmp/prombiztech-rollback-a12/deploy/production/compose.yaml
    env: /srv/prombiztech-production/env/production.env

Для rollback восстановить backup поверх `prombiz-production.yml`, затем:

    docker update --restart=unless-stopped prombiztech-production-web
    docker start prombiztech-production-web

Traefik монтирует dynamic directory read-only. На ZUER backup можно восстановить
через Ansible playbook либо одноразовый helper container с RW bind mount.
После восстановления обязательно проверить public `/`, `/healthz`, TLS и `www`.
Kubernetes resources и image при этом можно оставить для диагностики.
