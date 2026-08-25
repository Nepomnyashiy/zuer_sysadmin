# Ход-отчёт: ZUER secrets hygiene

Дата: 2026-08-22

## Цель

Удалить Anaconda credentials из tracked current tree и relevant Git history,
внедрить encrypted Ansible Vault и передать deployment-agent проверенный
allowlisted Kubernetes Secret workflow.

## Что сделано

- Проинвентаризированы branches, tags, remote refs, env-файлы, manifests,
  scripts и документация `zuer_sysadmin` и `anaconda-mvp`.
- Локальный Anaconda `.env` сохранён без изменения значений, исключён Git и
  переведён в mode `600`.
- Создан и проверен rollback Git bundle до history rewrite.
- `git filter-repo` удалил целевые literals из обеих remote branches Anaconda.
- Source current tree получил безопасный `.env.example`; deploy output удалён,
  Compose/Ansible defaults переведены на обязательные runtime values, setup
  script больше не печатает private SSH key.
- Force-with-lease выполнен только для `main` и
  `agent/anaconda-k8s-readiness`.
- Создан encrypted `ansible/group_vars/vault.yml` с секциями
  `vault_anaconda` и `vault_kolos`.
- Добавлен `ansible/k8s-anaconda-secret.yml` и Makefile interface для client
  dry-run и явного apply.
- Generic env-helper переведён в fail-closed режим: allowlist обязателен.

## Изменённые файлы

- Anaconda source: `.env.example`, `.gitignore`, Compose/Ansible templates,
  setup/docs; удалён tracked deploy output.
- Sysadmin: encrypted Vault, Secret playbook, Makefile, helper, task/runbook,
  readiness report и secrets-management skill.

## Выполненные команды

- Git inventory, `git bundle create/verify`, `git filter-repo`.
- Gitleaks current-tree/history scans с redaction.
- Exact-value scans через protected pattern files.
- `ansible-vault encrypt/view` с metadata-only проверкой.
- `ansible-playbook --syntax-check`.
- `make anaconda-secret-dry-run`.
- Force-with-lease push двух Anaconda branches и fresh remote mirror scan.

## Проверки

- Anaconda rewritten remote history: gitleaks clean, exact scan clean.
- Sysadmin current tree: gitleaks clean, exact scan clean.
- Anaconda `.env`: untracked, mode `600`.
- Vault password directory/file: `700`/`600`.
- Vault: encrypted AES256 header, четыре required Anaconda keys present.
- Kubernetes workflow: exact allowlist, client dry-run OK, apply skipped.
- Branch topology: rewritten `main` остаётся предком readiness branch.

## Результат

`SECRETS HYGIENE: READY`. Secrets blocker Anaconda rollout снят. Runtime
Anaconda и Traefik routing не изменялись.

## Найденные проблемы

- Credentials присутствовали в нескольких historical source paths и обеих
  remote branches.
- Legacy deploy output содержал host facts и SSH public-key metadata.
- Generic env-helper разрешал импорт всего `.env` без allowlist.
- Во время cleanup диагностический поиск ошибочно захватил temporary
  replacement artifact и вывел его в session tool log. Artifact удалён; данные
  не попали в Git или документацию.

## Риски

- Existing test credentials намеренно не ротированы по решению пользователя.
- History rewrite не очищает сторонние clones, forks и caches.
- Session tool log является дополнительным местом раскрытия в рамках текущей
  сессии.
- Перед реальным production использованием Telegram/IMAP credentials должны
  быть перевыпущены.

## Что осталось

- Deployment-agent выполняет повторный Secret dry-run, app dry-run/diff,
  явный Secret/app apply, rollout и smoke test.
- После smoke test отдельно выполняется Traefik cutover.

## Следующий шаг

```bash
git fetch --all --prune
git pull --ff-only
make anaconda-secret-dry-run
make app-dry-run APP=anaconda
make app-diff APP=anaconda
```

Только после проверки diff: `make anaconda-secret-apply`, затем app apply.

## Rollback

- Pre-rewrite Anaconda refs восстанавливаются из защищённого bundle:
  `/home/nsadmin/.local/share/osnova/backups/anaconda-mvp-pre-secrets-rewrite-20260821.bundle`.
- Source cleanup откатывается revert commit `41f5a8f`.
- Sysadmin изменения откатываются тематическим revert commit.
- Kubernetes rollback не требуется: Secret apply и application rollout в этой
  задаче не выполнялись.
