# Ход-отчёт: корректирующий rollout Anaconda Site

Дата: 2026-08-24

## Цель

Заменить ошибочно развёрнутый `anaconda_mvp` на фактический проект
`/run/media/nsadmin/godny_soft/site/anaconda_site`, не потеряв созданный PVC и
не затронув чужой dirty source checkout.

## Source

- Repository: `Nepomnyashiy/anaconda_site`.
- Branch: `agent/anaconda-site-k8s`.
- Commit: `22a7f3f`.
- Основной checkout `master` оставлен нетронутым; работа выполнена в отдельном
  `/tmp/anaconda-site-k8s-worktree`.

## Что сделано

- Определено, что приложение является статическим React/Vite-сайтом без API,
  PostgreSQL, Redis и runtime secrets.
- Из current source tree удалены tracked `.env` и legacy Ansible/PM2/UFW stack.
- Удалена Vite-инъекция Gemini key в browser bundle.
- Tailwind CDN/importmap заменены локальной Vite/Tailwind production-сборкой.
- Toolchain обновлён; `npm audit` показывает 0 vulnerabilities.
- Добавлен pinned multi-stage Dockerfile и unprivileged Nginx `101:8080`.
- Опубликован `anaconda/site:git-22a7f3f` с digest
  `sha256:32eeaa7ff31bf13804366aff257475d1b2ed0bb9d5401d357d465b1eb49b0585`.
- Active Kubernetes manifests сведены к Namespace, site Deployment, ClusterIP
  Service и одному web Ingress host.
- Ошибочный MVP API/web/PostgreSQL масштабирован в `0`; objects, Secret, PVC,
  PV и baseline dump сохранены.
- Edge desired state исправлен до одного router `anaconda.godny.tech`.

## Проверки

- npm production build: OK; npm audit: 0 vulnerabilities.
- Exact-value bundle scan: OpenRouter/Gemini keys absent.
- Container: user `101`, size около 5.9 MB.
- Container `/healthz`, `/`, SPA fallback: HTTP 200.
- Kubernetes server dry-run/diff: только новый site и Ingress switch.
- Deployment `anaconda-site`: `1/1 Ready`, restart count 0.
- Internal NodePort smoke: HTTP 200.
- Public `https://anaconda.godny.tech`: HTTP 200, TLS verification 0.
- Public page title: `Anaconda - Chaos to Order`.
- Resource usage: около 1m CPU / 14 MiB RAM.
- Node `Ready`; MemoryPressure/DiskPressure `False`.

## Retained legacy resources

- Deployments `anaconda-api`, `anaconda-web`: replicas 0.
- StatefulSet `anaconda-postgres`: replicas 0.
- Internal Services и `anaconda-secret` сохранены.
- PVC `data-anaconda-postgres-0`: Bound 20 GiB; PV policy `Retain`.
- Baseline dump сохранён в `/mnt/ufiles/k8s-backups/postgres/anaconda/`.

Удаление этих объектов или PVC не выполнялось и требует отдельного
подтверждения.

## Security findings

- Реальные OpenRouter/Gemini keys присутствуют в старой source history.
- Current branch и production image не содержат keys.
- Keys необходимо отозвать; history rewrite/force-push требует backup и явного
  подтверждения пользователя.

## Что осталось

- Интерактивно применить обновлённый edge template, чтобы удалить legacy API
  router из live `k8s-anaconda.yml`.
- После подтверждения подготовить source history cleanup.
- Отдельно решить судьбу retained MVP/PVC resources.

## Rollback

- Site: применить предыдущий Ingress/backend/image из Git history.
- Legacy MVP: вернуть replicas API/web/PostgreSQL в `1`; PVC/PV не удалялись.
- Edge: Ansible сохраняет backup предыдущего standalone route-файла.
