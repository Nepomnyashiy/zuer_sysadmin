# PromBiz.Tech Kubernetes cutover — 2026-08-25

## Result

`https://prombiz.tech` is served by the PromBiz.Tech static site from Kubernetes
on ZUER:

```text
Docker Traefik
-> http://192.168.0.101:30080
-> ingress-nginx
-> Ingress prombiz
-> ClusterIP prombiz-site:8080
-> Deployment prombiz-site
```

The production image is pinned to:

```text
127.0.0.1:30500/prombiz/site@sha256:dc173606762e62fb167a549dadde293a491f7c473411f1d8db057495a5a27dd1
```

At cutover the Pod was `1/1 Ready` with zero restarts. Internal Host-header
checks and public `/` and `/healthz` returned `200`. `www.prombiz.tech` returned
`301` to `https://prombiz.tech/`. The existing Let's Encrypt certificate was
valid. `anaconda.godny.tech`, `cloud.godny.tech` and `traefik.godny.tech` retained
their expected responses.

## Frozen legacy production

The old production project was retained intact:

```text
source: /run/media/nsadmin/godny_soft/soft/prombiztech
container: prombiztech-production-web
image: prombiztech-web@sha256:a9832f9189a091c9c374605d99e06f2f0f9f389353062afbf9f1a5d5a282736a
compose: /tmp/prombiztech-rollback-a12/deploy/production/compose.yaml
env file: /srv/prombiztech-production/env/production.env
persistent mounts: none
state: FROZEN, stopped, restart=no
```

The staging container was not changed.

## Rollback

The pre-cutover Traefik route is preserved at:

```text
/srv/proxy/traefik/dynamic/prombiz-production.pre-k8s.yml.bak
```

1. Restore that file over `/srv/proxy/traefik/dynamic/prombiz-production.yml`.
2. Set `prombiztech-production-web` restart policy to `unless-stopped`.
3. Start `prombiztech-production-web`.
4. Verify public `/`, `/healthz`, TLS and the canonical `www` redirect.

Traefik mounts `/srv/proxy/traefik/dynamic` read-only inside its main container.
Use the committed Ansible playbook or a one-shot helper container with an explicit
RW bind mount to restore the file. Do not remove the Kubernetes deployment during
rollback; retain it for diagnosis.
