# PromBiz.Tech — site onboarding and Kubernetes integration

**Status:** COMPLETE
**Project repo:** `Nepomnyashiy/anaconda_web`  
**Project branch:** `agent/prombiz-rebrand`

## Цель

Подготовить новый корпоративный сайт PromBiz.Tech на базе существующего Anaconda site и интегрировать его в стандартную платформу ZUER.

Целевой host:

```text
https://prombiz.tech
```

`www.prombiz.tech` должен редиректить на canonical.

## Project checkout

Ожидаемый путь:

```text
/run/media/nsadmin/godny_soft/soft/anaconda_web
```

## Целевая архитектура

```text
Astro static build
-> unprivileged Nginx :8080
-> image 127.0.0.1:30500/prombiz/site:git-<sha>
-> namespace prombiz
-> Deployment prombiz-site
-> ClusterIP Service
-> Ingress
-> ingress-nginx
-> Docker Traefik
-> prombiz.tech
```

## Platform work

- [x] Синхронизировать проект после завершения brand/architecture cleanup.
- [x] Создать `apps/prombiz/k8s/`.
- [x] Добавить build/push поддержку `APP=prombiz` в существующий framework.
- [x] Подготовить Deployment/Service/Ingress.
- [x] Добавить readiness/liveness/resources/securityContext.
- [x] Build immutable image и push local registry.
- [x] Server-side dry-run/diff.
- [x] Проверить NodePort Host routing до edge.
- [x] Проверить текущий DNS/старый hosting.
- [x] Подготовить Traefik route.
- [x] Выполнить cutover только после готовности Kubernetes site.
- [x] Проверить TLS/200/redirect www.
- [x] Отключить старую публикацию после успешной проверки.
- [x] Сохранить rollback до подтверждения стабильности.
- [x] Подключить monitoring после deployment.

## Ограничения

- Не менять current Anaconda/Kolos tasks без необходимости.
- Не отключать старый `prombiz.tech` заранее.
- Не публиковать backend/DB, если corporate site их не использует.
- Platform manifests являются source of truth в sysadmin, а не в frontend repo.

## Handoff

Project agent должен сначала завершить `tasks/CURRENT.md` в `anaconda_web@agent/prombiz-rebrand`, затем перейти к этой platform task.

## Production result — 2026-08-25

- Source: `anaconda_web@agent/prombiz-rebrand`, image tag `git-3bdc760`.
- Registry digest: `sha256:dc173606762e62fb167a549dadde293a491f7c473411f1d8db057495a5a27dd1`.
- `prombiz/prombiz-site`: `1/1 Ready`, zero restarts at cutover.
- `prombiz-site` is a ClusterIP Service; application NodePort was not created.
- Docker Traefik forwards `prombiz.tech` to ingress-nginx at `192.168.0.101:30080`.
- Public `/` and `/healthz` return `200`; `www` returns permanent `301` to canonical.
- TLS certificate for `prombiz.tech` is valid and issued by Let's Encrypt.
- Legacy `prombiztech-production-web` is `FROZEN`: stopped with `restart=no`.
- Legacy source, container, image, Compose file and route backup were retained.
- `anaconda.godny.tech` remained `200` before and after cutover.

The Ansible check was blocked by interactive local sudo authentication. The exact
reviewed template was applied through a one-shot Docker helper against the Traefik
bind mount; the active route is still represented by the committed playbook/template.
See `apps/prombiz/README.md` and
`docs/reports/2026-08-25-prombiz-site-cutover.md` for rollback.
