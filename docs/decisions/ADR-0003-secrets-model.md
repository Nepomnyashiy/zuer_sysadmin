# ADR-0003: Secrets через локальные env и генерацию Kubernetes Secret

Дата: 2026-07-10
Статус: accepted

## Контекст

В проектах есть `.env` с токенами Telegram, IMAP/SMTP, YooKassa, Strapi и
database credentials. Plain Kubernetes Secret YAML нельзя коммитить.

## Решение

Хранить реальные секреты только локально в `.env` или защищенных файлах.
Kubernetes Secret создавать скриптом `scripts/k8s/create-secret-from-env.sh`.
В Git хранить только `.env.example`, шаблоны и документацию.

## Последствия

- Git остается безопасным source of truth для manifests.
- Секреты воспроизводимо создаются перед deploy.
- Для production позже можно перейти на SOPS, Sealed Secrets или External
  Secrets без смены модели приложения.

## Альтернативы

- Plain Secret YAML в Git: запрещено.
- Ansible Vault: допустимо для host-level секретов, но менее удобно для app
  overlays.
- SOPS/Sealed Secrets: целевой вариант после стабилизации платформы.

## Rollback

Secret можно пересоздать из старого `.env`. Удаление secrets не должно
сопровождаться удалением PVC или данных.

