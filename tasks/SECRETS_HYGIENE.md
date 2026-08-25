# SECRETS_HYGIENE — Очистка и стандартизация секретов

**Status:** READY
**Server:** ZUER  
**Priority:** HIGH  
**Created:** 2026-08-21  
**Completed:** 2026-08-22
**Type:** Focused maintenance task

## Цель

Навести порядок в хранении секретов до продолжения Anaconda rollout:

1. удалить plaintext credentials из Git history;
2. сохранить текущие тестовые значения без перевыпуска;
3. исключить реальные `.env` из Git;
4. создать единый Ansible Vault source of truth;
5. настроить allowlisted delivery в Kubernetes Secret;
6. не раскрывать secret values в чатах, task-файлах, логах и commit messages;
7. после успешной проверки снять blocker основной задачи `tasks/CURRENT.md`.

## Важное решение пользователя

На текущем тестовом этапе **не ротировать** существующие Telegram/IMAP credentials.

Не генерировать новые ключи и не менять значения без отдельного запроса.

При этом зафиксировать residual risk:

- секрет, однажды опубликованный в Git history, мог быть скопирован;
- history rewrite не удаляет сторонние clones/forks/caches;
- перед реальным production использованием эти credentials должны быть перевыпущены.

Для текущего тестового rollout пользователь этот риск принимает.

## Обязательный skill

Прочитать до работы:

```text
skills/secrets-management/SKILL.md
docs/runbooks/secrets-management.md
```

## Scope

Основной infrastructure repo:

```text
/run/media/nsadmin/godny_soft/soft/sysadmin
```

Anaconda source repo:

```text
/run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp
```

Рабочая source-ветка readiness:

```text
agent/anaconda-k8s-readiness
```

Не предполагать, что только одна ветка содержит старые значения. Проверить все релевантные refs.

## Phase 1 — Inventory без раскрытия значений

- [x] Проверить git status/branches/remotes обоих репозиториев.
- [x] Определить tracked `.env`/secret-like files.
- [x] Определить key names, которые считаются чувствительными.
- [x] Проверить current tree на plaintext secrets.
- [x] Проверить Git history/branches/tags через secret scanner.
- [x] Не выводить найденные secret values в отчёты.
- [x] Зафиксировать только repository/path/ref/key-name/status.

Предпочтительные инструменты:

```text
gitleaks
git filter-repo
```

Если отсутствуют — установить минимально необходимым безопасным способом или использовать эквивалентный инструмент.

## Phase 2 — Backup перед history rewrite

History rewrite считается HIGH RISK Git operation.

Перед изменением истории:

- [x] убедиться, что текущие изменения сохранены;
- [x] не потерять чужой dirty worktree;
- [x] сохранить список branches/tags/remote refs;
- [x] создать rollback snapshot (`git bundle` или mirror backup) вне рабочего дерева;
- [x] проверить, что backup читается;
- [x] зафиксировать rollback procedure без secret values.

Не удалять backup до полной remote verification.

## Phase 3 — Current tree hygiene

Для Anaconda и других затронутых репозиториев:

- [x] реальные `.env` должны быть untracked;
- [x] `.gitignore` должен исключать `.env`/секретные варианты;
- [x] `.env.example` должен содержать только key names/placeholders;
- [x] права локальных secret files — `600`;
- [x] manifests не должны содержать plaintext credentials;
- [x] docs/tasks/reports не должны содержать plaintext credentials;
- [x] shell scripts не должны содержать literals.

## Phase 4 — Ansible Vault standard

В `zuer_sysadmin` подготовить production-like secret source:

```text
ansible/group_vars/vault.yml
```

Он должен находиться в Git только в encrypted Ansible Vault формате.

Создать/проверить password file вне Git:

```text
/home/nsadmin/.config/osnova/ansible-vault-pass
```

Права:

```text
dir: 700
file: 600
```

Не читать пароль в чат/отчёт.

Vault должен содержать логические секции минимум для Anaconda и быть расширяемым для Kolos и следующих приложений.

Не помещать реальное plaintext содержимое Vault в task/report.

## Phase 5 — Kubernetes Secret delivery

Для Anaconda оставить строгий allowlist:

```text
POSTGRES_PASSWORD
TELEGRAM_BOT_TOKEN
EMAIL_IMAP_USER
EMAIL_IMAP_PASSWORD
```

- [x] проверить существующий helper `create-secret-from-env.sh`;
- [x] не импортировать весь `.env`;
- [x] подготовить целевой Ansible workflow для создания `anaconda-secret` из Vault;
- [x] Secret values не должны попадать в generated Git files;
- [x] проверять только metadata/key names/status.

## Phase 6 — Git history cleanup

Очистить secret literals из истории затронутого source repository с помощью `git filter-repo` или эквивалентного безопасного rewrite.

Требования:

- [x] определить все affected branches/tags;
- [x] не вставлять secret values в командную строку, если это оставляет их в shell history;
- [x] использовать локальный replacement/pattern file с `chmod 600`, если он нужен;
- [x] выполнить rewrite;
- [x] повторно прогнать secret scan по rewritten refs;
- [x] убедиться, что необходимые source commits/изменения сохранены логически;
- [x] проверить branch topology после rewrite.

## Phase 7 — Remote synchronization

После успешного локального scan:

- [x] подготовить список refs, которые требуют force-push;
- [x] force-push только очищенные refs;
- [x] не затрагивать нерелевантные repositories/branches;
- [x] повторно проверить remote history;
- [x] проверить GitHub branches/tags;
- [x] учесть, что старые commit SHA после rewrite станут недействительными.

Если `zuer_sysadmin` содержит ссылки на старые source commit SHA — обновить их на новые SHA.

## Phase 8 — Documentation sync

После завершения:

- [x] обновить этот task;
- [x] обновить `tasks/CURRENT.md`;
- [x] обновить `docs/reports/2026-08-21-anaconda-production-readiness.md`, если старые SHA изменились;
- [x] обновить runbook/skill только если найдено reusable knowledge;
- [x] не записывать secret values.

## Phase 9 — Handoff основной задаче

Основной deployment-agent должен получить из Git только состояние:

```text
SECRETS HYGIENE: READY
```

и затем выполнить:

```text
git fetch/pull
-> прочитать tasks/CURRENT.md
-> повторный Secret dry-run/diff
-> Anaconda apply
-> rollout
-> smoke
-> Traefik routes
```

Не выполнять сам Anaconda production rollout в рамках этой focused task, если это не требуется для проверки Secret workflow.

## Completion result

```text
SECRETS HYGIENE: READY
```

- Anaconda `main` rewritten tip: `97ee84d`.
- Anaconda `agent/anaconda-k8s-readiness` tip: `41f5a8f`.
- Relevant remote branches прошли fresh-clone gitleaks и exact-value scan.
- `.env` сохранён локально, untracked, mode `600`; `.env.example` безопасен.
- Encrypted `ansible/group_vars/vault.yml` создан и содержит четыре Anaconda
  keys в логической секции `vault_anaconda`.
- Vault password остаётся вне Git: `/home/nsadmin/.config/osnova/ansible-vault-pass`.
- `make anaconda-secret-dry-run` успешен; apply не выполнялся.
- Rollback bundle проверен и сохранён в
  `/home/nsadmin/.local/share/osnova/backups/anaconda-mvp-pre-secrets-rewrite-20260821.bundle`.
- Existing test credentials намеренно не ротированы. Перед production они
  должны быть перевыпущены.
- Во время cleanup один diagnostic command захватил temporary replacement
  artifact и вывел его в session tool log. Artifact удалён; значения не попали
  в repository, commits, tasks или reports. Это дополнительный residual risk.

## Definition of Done

- [x] plaintext secrets отсутствуют в tracked current tree;
- [x] current relevant Git history очищена;
- [x] remote refs очищены и проверены;
- [x] `.env` untracked и защищён правами;
- [x] `.env.example` безопасен;
- [x] Ansible Vault создан/зашифрован;
- [x] vault password хранится вне Git;
- [x] Kubernetes Secret workflow использует allowlist;
- [x] secret scan после rewrite не показывает целевые credentials;
- [x] rollback backup сохранён до финальной проверки;
- [x] `tasks/CURRENT.md` обновлён;
- [x] основной deployment blocker снят;
- [x] изменения закоммичены и отправлены в GitHub.

## Финальный отчёт

Формат:

```text
SECRETS HYGIENE: READY / BLOCKED

Repositories processed:
- ...

Current tree:
- ...

History cleanup:
- ...

Ansible Vault:
- ...

Kubernetes Secret workflow:
- ...

Remote verification:
- ...

Residual risk:
- credentials intentionally not rotated for test stage

Commits / rewritten refs:
- ...

Handoff:
- previous deployment-agent may continue / may not continue
```

Никогда не включать реальные secret values в финальный отчёт.
