# PromBiz.Tech — site onboarding and Kubernetes integration

**Status:** PLANNED  
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
/run/media/nsadmin/godny_soft/soft/PromBizTech
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

- [ ] Синхронизировать проект после завершения brand/architecture cleanup.
- [ ] Создать `apps/prombiz/k8s/`.
- [ ] Добавить build/push поддержку `APP=prombiz` в существующий framework.
- [ ] Подготовить Deployment/Service/Ingress.
- [ ] Добавить readiness/liveness/resources/securityContext.
- [ ] Build immutable image и push local registry.
- [ ] Server-side dry-run/diff.
- [ ] Проверить NodePort Host routing до edge.
- [ ] Проверить текущий DNS/старый hosting.
- [ ] Подготовить Traefik route.
- [ ] Выполнить cutover только после готовности Kubernetes site.
- [ ] Проверить TLS/200/redirect www.
- [ ] Отключить старую публикацию после успешной проверки.
- [ ] Сохранить rollback до подтверждения стабильности.
- [ ] Подключить monitoring после deployment.

## Ограничения

- Не менять current Anaconda/Kolos tasks без необходимости.
- Не отключать старый `prombiz.tech` заранее.
- Не публиковать backend/DB, если corporate site их не использует.
- Platform manifests являются source of truth в sysadmin, а не в frontend repo.

## Handoff

Project agent должен сначала завершить `tasks/CURRENT.md` в `anaconda_web@agent/prombiz-rebrand`, затем перейти к этой platform task.
