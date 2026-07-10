# ADR-0004: local-path storage на /mnt/ufiles/k8s

Дата: 2026-07-10
Статус: accepted

## Контекст

На сервере есть большой ext4-диск `/mnt/ufiles`, уже используемый для backups и
данных. Kubernetes нужен storage backend для PVC.

## Решение

Использовать `local-path-provisioner` k3s и выделить путь
`/mnt/ufiles/k8s/local-path` для PVC.

## Последствия

- PVC создаются декларативно и не требуют ручных hostPath для каждого сервиса.
- Данные остаются локальными на single-node хосте.
- Backup обязателен, потому что storage не реплицируется между узлами.

## Альтернативы

- Longhorn: полезен для multi-node, избыточен на первом single-node этапе.
- NFS: можно использовать позже для shared storage.
- HostPath вручную: просто, но плохо масштабируется при добавлении приложений.

## Rollback

Перед удалением PVC делать backup. Каталог `/mnt/ufiles/k8s/local-path` не
удалять автоматически.

