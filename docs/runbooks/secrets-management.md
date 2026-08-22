# Runbook: Secrets Management on ZUER

## Цель

Установить единый практический способ хранения и доставки секретов для приложений ZUER без plaintext credentials в Git.

## Стандарт

```text
Git
├── обычная конфигурация
├── .env.example
└── encrypted Ansible Vault

ZUER
├── local .env (optional/bootstrap)
└── ~/.config/osnova/ansible-vault-pass

Ansible
└── создаёт allowlisted Kubernetes Secret
```

## 1. Локальные env-файлы

Реальные `.env` не должны отслеживаться Git.

Проверить `.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

Права:

```bash
chmod 600 .env
```

Проверка tracked env:

```bash
git ls-files | grep -E '(^|/)\.env($|\.)' || true
```

## 2. Ansible Vault

Создать или использовать:

```text
ansible/group_vars/vault.yml
```

Редактировать через:

```bash
ansible-vault edit \
  --vault-password-file ~/.config/osnova/ansible-vault-pass \
  ansible/group_vars/vault.yml
```

Не использовать `cat` для вывода содержимого Vault в терминальные отчёты.

## 3. Vault password

Стандартный путь:

```text
~/.config/osnova/ansible-vault-pass
```

Создание каталога:

```bash
mkdir -p ~/.config/osnova
chmod 700 ~/.config/osnova
chmod 600 ~/.config/osnova/ansible-vault-pass
```

Сам пароль вводится пользователем локально и не коммитится.

## 4. Kubernetes Secret

Secret создаётся только из allowlisted keys.

Для Anaconda текущий allowlist:

```text
POSTGRES_PASSWORD
TELEGRAM_BOT_TOKEN
EMAIL_IMAP_USER
EMAIL_IMAP_PASSWORD
```

Основной Anaconda workflow использует encrypted Vault:

```bash
make anaconda-secret-dry-run
make anaconda-secret-apply
```

Playbook `ansible/k8s-anaconda-secret.yml` передаёт manifest через stdin,
использует `no_log` и не создаёт промежуточный plaintext-файл. Dry-run является
default; apply требует отдельной явной команды.

Helper `scripts/k8s/create-secret-from-env.sh` остаётся bootstrap/fallback
вариантом. Он требует хотя бы один allowlisted key и запрещает импорт всего
`.env`.

## 5. Проверка без раскрытия значений

```bash
kubectl -n anaconda get secret anaconda-secret
```

Разрешено проверять key names/metadata, но не декодировать значения в общий лог или чат.

## 6. Если secret попал в Git history

Production-safe подход:

```text
rotate/revoke
+
history cleanup
```

Для текущего тестового этапа пользователь принял решение временно сохранить существующие значения и выполнить history cleanup без ротации.

Residual risk должен оставаться задокументированным: удаление из Git history не удаляет возможные сторонние clones, forks или caches. Перед реальным production использованием такие credentials должны быть перевыпущены.

## 7. History cleanup workflow

History rewrite выполнять отдельной задачей `tasks/SECRETS_HYGIENE.md`.

Общий порядок:

```text
inventory
-> backup
-> identify affected refs
-> rewrite with git filter-repo
-> scan rewritten refs
-> force-push cleaned refs
-> verify remote
-> cleanup temporary artifacts
-> document result
```

Не включать secret values в команды, commit messages и task-файлы, если можно использовать replacement files/pattern files с безопасными локальными правами.

## 8. Что делать после cleanup

1. Обновить Ansible Vault.
2. Убедиться, что `.env` не tracked.
3. Прогнать secret scan current tree + history.
4. Обновить `tasks/SECRETS_HYGIENE.md`.
5. Обновить `tasks/CURRENT.md` и снять blocker deployment.
6. Предыдущий deployment-agent делает `git fetch/pull`, читает обновлённый task state и продолжает Anaconda rollout.
