# SECRETS_HYGIENE — Очистка и стандартизация секретов

**Status:** ACTIVE  
**Server:** ZUER  
**Priority:** HIGH  
**Created:** 2026-08-21  
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

- [ ] Проверить git status/branches/remotes обоих репозиториев.
- [ ] Определить tracked `.env`/secret-like files.
- [ ] Определить key names, которые считаются чувствительными.
- [ ] Проверить current tree на plaintext secrets.
- [ ] Проверить Git history/branches/tags через secret scanner.
- [ ] Не выводить найденные secret values в отчёты.
- [ ] Зафиксировать только repository/path/ref/key-name/status.

Предпочтительные инструменты:

```text
gitleaks
git filter-repo
```

Если отсутствуют — установить минимально необходимым безопасным способом или использовать эквивалентный инструмент.

## Phase 2 — Backup перед history rewrite

History rewrite считается HIGH RISK Git operation.

Перед изменением истории:

- [ ] убедиться, что текущие изменения сохранены;
- [ ] не потерять чужой dirty worktree;
- [ ] сохранить список branches/tags/remote refs;
- [ ] создать rollback snapshot (`git bundle` или mirror backup) вне рабочего дерева;
- [ ] проверить, что backup читается;
- [ ] зафиксировать rollback procedure без secret values.

Не удалять backup до полной remote verification.

## Phase 3 — Current tree hygiene

Для Anaconda и других затронутых репозиториев:

- [ ] реальные `.env` должны быть untracked;
- [ ] `.gitignore` должен исключать `.env`/секретные варианты;
- [ ] `.env.example` должен содержать только key names/placeholders;
- [ ] права локальных secret files — `600`;
- [ ] manifests не должны содержать plaintext credentials;
- [ ] docs/tasks/reports не должны содержать plaintext credentials;
- [ ] shell scripts не должны содержать literals.

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

- [ ] проверить существующий helper `create-secret-from-env.sh`;
- [ ] не импортировать весь `.env`;
- [ ] подготовить целевой Ansible workflow для создания `anaconda-secret` из Vault;
- [ ] Secret values не должны попадать в generated Git files;
- [ ] проверять только metadata/key names/status.

## Phase 6 — Git history cleanup

Очистить secret literals из истории затронутого source repository с помощью `git filter-repo` или эквивалентного безопасного rewrite.

Требования:

- [ ] определить все affected branches/tags;
- [ ] не вставлять secret values в командную строку, если это оставляет их в shell history;
- [ ] использовать локальный replacement/pattern file с `chmod 600`, если он нужен;
- [ ] выполнить rewrite;
- [ ] повторно прогнать secret scan по rewritten refs;
- [ ] убедиться, что необходимые source commits/изменения сохранены логически;
- [ ] проверить branch topology после rewrite.

## Phase 7 — Remote synchronization

После успешного локального scan:

- [ ] подготовить список refs, которые требуют force-push;
- [ ] force-push только очищенные refs;
- [ ] не затрагивать нерелевантные repositories/branches;
- [ ] повторно проверить remote history;
- [ ] проверить GitHub branches/tags;
- [ ] учесть, что старые commit SHA после rewrite станут недействительными.

Если `zuer_sysadmin` содержит ссылки на старые source commit SHA — обновить их на новые SHA.

## Phase 8 — Documentation sync

После завершения:

- [ ] обновить этот task;
- [ ] обновить `tasks/CURRENT.md`;
- [ ] обновить `docs/reports/2026-08-21-anaconda-production-readiness.md`, если старые SHA изменились;
- [ ] обновить runbook/skill только если найдено reusable knowledge;
- [ ] не записывать secret values.

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

## Definition of Done

- [ ] plaintext secrets отсутствуют в tracked current tree;
- [ ] current relevant Git history очищена;
- [ ] remote refs очищены и проверены;
- [ ] `.env` untracked и защищён правами;
- [ ] `.env.example` безопасен;
- [ ] Ansible Vault создан/зашифрован;
- [ ] vault password хранится вне Git;
- [ ] Kubernetes Secret workflow использует allowlist;
- [ ] secret scan после rewrite не показывает целевые credentials;
- [ ] rollback backup сохранён до финальной проверки;
- [ ] `tasks/CURRENT.md` обновлён;
- [ ] основной deployment blocker снят;
- [ ] изменения закоммичены и отправлены в GitHub.

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
