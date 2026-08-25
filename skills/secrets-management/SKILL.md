# Secrets Management Skill

## Назначение

Этот skill задаёт единый стандарт хранения, доставки, проверки и очистки секретов для ZUER, Kubernetes и приложений OSNOVA/GodnySoft.

Цель: реальные credentials не должны храниться в открытом виде в Git, manifests, task-файлах, документации, логах или чатах.

## Базовая архитектура

```text
Git
├── manifests / ConfigMap / templates
├── .env.example
├── encrypted Ansible Vault
└── docs / runbooks

Server only
├── local .env (при необходимости)
└── vault password file вне Git

Ansible
└── читает Ansible Vault и формирует runtime Secret

Kubernetes
└── Secret -> Pod
```

## Классификация данных

### Обычная конфигурация

Разрешено хранить в Git и ConfigMap:

- hostnames;
- ports;
- public URLs;
- feature flags без чувствительных значений;
- имена баз данных;
- имена пользователей, если они не являются секретом;
- non-sensitive application settings.

### Секреты

Хранить только через утверждённый secret workflow:

- пароли;
- API keys;
- Telegram bot tokens;
- IMAP/SMTP app passwords;
- JWT signing secrets;
- OAuth client secrets;
- database passwords;
- private keys;
- cookie/session secrets;
- webhook signing secrets.

## Источник истины

Для production-like секретов ZUER стандартом является **Ansible Vault**.

Рекомендуемая структура:

```text
ansible/group_vars/
├── all.yml
└── vault.yml
```

`vault.yml` хранится в Git только в зашифрованном виде.

Пример структуры до шифрования:

```yaml
vault_anaconda:
  postgres_password: "..."
  telegram_bot_token: "..."
  email_imap_user: "..."
  email_imap_password: "..."

vault_kolos:
  database_password: "..."
  app_keys: "..."
  admin_jwt_secret: "..."
```

Не использовать реальные значения в примерах, docs или task-файлах.

## Vault password

Пароль Ansible Vault не хранить в Git.

Стандартный путь на ZUER:

```text
/home/nsadmin/.config/osnova/ansible-vault-pass
```

Права:

```bash
chmod 700 /home/nsadmin/.config/osnova
chmod 600 /home/nsadmin/.config/osnova/ansible-vault-pass
```

Никогда не выводить содержимое password file в отчёт, чат или лог.

## Локальный .env

Локальный `.env` допустим для bootstrap, разработки и временного runtime source, если:

- файл не отслеживается Git;
- `.gitignore` исключает `.env` и чувствительные варианты;
- права файла `600`;
- в Git хранится только `.env.example` без значений.

Рекомендуемый `.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

Проверка:

```bash
git ls-files | grep -E '(^|/)\.env($|\.)' || true
```

## Kubernetes Secret

Не импортировать весь `.env` в Kubernetes автоматически.

Использовать allowlist только необходимых keys.

Правильная модель:

```text
Ansible Vault
-> allowlisted variables
-> Kubernetes Secret
-> Pod
```

или временно:

```text
local .env
-> allowlisted keys
-> Kubernetes Secret
```

Не использовать без анализа:

```bash
kubectl create secret generic app-secret --from-env-file=.env
```

потому что это может унести в cluster лишние значения.

## Работа агента с секретами

Агент имеет право:

- проверять наличие key names;
- проверять, что Secret существует;
- проверять количество ожидаемых keys;
- сравнивать allowlist;
- создавать Secret из уже подготовленного secure source;
- проверять `.gitignore`;
- искать подозрительные tracked files;
- выполнять secret scanning без печати найденных значений.

Агент не должен:

- печатать secret values;
- вставлять secret values в Markdown;
- добавлять secrets в task/report;
- коммитить plaintext secrets;
- передавать значения в CLI так, чтобы они попадали в shell history, если есть более безопасный способ;
- копировать секреты из Git history в отчёт.
- запускать рекурсивный поиск из каталога, содержащего temporary secret
  artifacts; scan scope должен быть явно ограничен repository checkout;
- печатать private keys из setup/deploy scripts вместо безопасной передачи в
  целевое secret storage.

В отчётах использовать только имена ключей и статус:

```text
TELEGRAM_BOT_TOKEN: present
EMAIL_IMAP_PASSWORD: present
POSTGRES_PASSWORD: present
```

## Secret scanning

Перед release проверять repository history и current tree инструментом, который доступен на сервере, например:

- `gitleaks`;
- `trufflehog`;
- GitHub secret scanning, если доступен;
- контролируемый `git grep` только по key names/patterns без публикации значений.

Не добавлять найденные значения в shell output, task или commit message.

## Секрет найден в Git history

Считать credential потенциально раскрытым, если он когда-либо попал в Git commit.

Стандартная production-рекомендация — rotation/revocation плюс history cleanup.

Если пользователь явно решает временно **не ротировать** тестовые credentials, агент может выполнить history cleanup, но обязан зафиксировать residual risk:

- history rewrite не гарантирует удаление значения из чужих clones/forks/caches;
- при public repository секрет следует считать потенциально известным третьей стороне;
- перед реальным production использованием credential должен быть перевыпущен.

Не блокировать тестовый rollout только по этой причине, если пользователь явно принял этот риск и history cleanup успешно завершён.

## Очистка Git history

History rewrite — HIGH RISK Git operation.

До выполнения:

1. определить точный repository;
2. убедиться, что рабочее дерево сохранено;
3. зафиксировать текущие refs;
4. создать backup mirror/bundle или другой rollback snapshot;
5. определить все branches/tags, где встречается секрет;
6. не печатать secret value;
7. подготовить план force-push;
8. получить явное подтверждение пользователя перед destructive rewrite/force-push, если оно ещё не дано текущей задачей.

Предпочтительный инструмент:

```text
git filter-repo
```

После rewrite:

- проверить current tree;
- проверить все refs;
- выполнить secret scan;
- force-push только очищенные refs;
- проверить remote повторно;
- удалить локальные temporary artifacts, содержащие секреты;
- обновить task и runbook.

## Не смешивать секреты и deployment

Secrets hygiene лучше выполнять отдельной сфокусированной задачей, если она включает history rewrite.

Основной deployment-agent должен дождаться завершения `tasks/SECRETS_HYGIENE.md`, затем синхронизировать repository и продолжить rollout с сохранённой точки.

## Definition of Done

Secret management считается приведённым в порядок, когда:

- plaintext secrets отсутствуют в tracked current tree;
- `.env` исключён Git и имеет корректные права;
- `.env.example` не содержит реальных значений;
- Ansible Vault создан и зашифрован;
- vault password находится вне Git;
- Kubernetes Secret создаётся только из allowlisted keys;
- current refs прошли secret scan;
- при history cleanup проверены branches/tags и remote;
- документация обновлена;
- ни одно secret value не появилось в task, commit message или отчёте.
