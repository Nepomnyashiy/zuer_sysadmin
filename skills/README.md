# Agent Skills

Этот каталог содержит переиспользуемые рабочие методики для агентов, которые администрируют сервер ZUER и платформу OSNOVA/GodnySoft.

## Как использовать

Свежий агент сначала читает `AGENTS.md`, затем `docs/agent/START_PROMPT.md`, `tasks/CURRENT.md` и только релевантные текущей задаче skills.

Не загружай все skills подряд без необходимости.

## Skills

- `system-startup/SKILL.md` — стартовый аудит системы и ресурсов.
- `kubernetes/SKILL.md` — работа с k3s/Kubernetes, Kustomize, Helm, rollout и storage.
- `devops/SKILL.md` — Linux, Docker, Traefik, DNS, TLS, Ansible, Git, CI/CD, backup.
- `application-deployment/SKILL.md` — единый стандарт публикации приложений на `*.godny.tech`.
- `monitoring-observability/SKILL.md` — Prometheus, Grafana, Loki, метрики, dashboards, alerts.
- `incident-diagnostics/SKILL.md` — диагностика инцидентов и деградаций.
- `documentation-sync/SKILL.md` — синхронизация tasks/docs/skills/Git после работы.
- `secrets-management/SKILL.md` — хранение секретов, Ansible Vault, allowlisted Kubernetes Secrets, secret scanning и безопасная очистка Git history.

## Разделение информации

```text
tasks/  = что сейчас делаем
docs/   = как фактически устроена инфраструктура
skills/ = как повторяемо выполнять работу
Git     = история изменений
```

Если во время задачи найдено универсальное решение, которое пригодится снова, оно должно быть перенесено из `tasks/CURRENT.md` в соответствующий skill или runbook.

Если изменилось фактическое устройство системы — обновляется `docs/`.

Если изменился статус работы — обновляется `tasks/CURRENT.md`.

Для задач, связанных с credentials, secret history или Kubernetes Secret, агент обязан дополнительно прочитать:

```text
skills/secrets-management/SKILL.md
docs/runbooks/secrets-management.md
```
