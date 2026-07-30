# Ход-отчёт: GNOME primary paste в bootstrap

Дата: 2026-07-30

## Цель

Сделать вставку выделенного текста средней кнопкой мыши воспроизводимой на
новой Ubuntu.

## Что сделано

- Добавлен отдельный Ansible playbook с системной настройкой GNOME.
- Playbook подключён к основному bootstrap.
- Добавлены обновление базы dconf и проверка эффективного значения.
- Документированы отдельные check/apply-команды.

## Изменённые файлы

- `ansible/bootstrap.yml`
- `ansible/desktop-settings.yml`
- `README.md`
- `ansible/README.md`
- `docs/reports/2026-07-30-gnome-primary-paste-bootstrap.md`

## Выполненные команды

- Проверка Git branch, status и последних коммитов.
- Поиск существующих bootstrap и desktop-настроек.
- Синтаксическая проверка Ansible playbooks.

## Проверки

- `ansible-playbook -i ansible/inventory.ini ansible/desktop-settings.yml --syntax-check`
- `ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml --syntax-check`
- `git diff --check`

Запуск `ansible-playbook ... desktop-settings.yml --check --diff` выполнен, но
остановился до первой задачи на запросе sudo-пароля. Полный dry-run с
привилегиями остаётся обязательным шагом перед apply.

## Результат

Bootstrap декларативно задаёт
`org.gnome.desktop.interface gtk-enable-primary-paste=true`.

## Найденные проблемы

Рабочее дерево уже содержало несвязанные незакоммиченные изменения. Они не
изменялись и не включались в эту итерацию.

Агентская среда не может передать пароль для Ansible `become`, поэтому
привилегированный check mode должен быть запущен пользователем в терминале.

## Риски

- Пользовательское значение dconf имеет приоритет над системным значением по
  умолчанию; runtime-проверка обнаружит такой конфликт.
- Настройка применима к приложениям, поддерживающим GTK primary selection.

## Что осталось

Выполнить check mode и изучить diff, затем отдельно подтвердить apply.

## Следующий шаг

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/desktop-settings.yml --check --diff
```

## Rollback

Удалить `/etc/dconf/db/local.d/00-osnova-desktop`, выполнить `dconf update` и
вернуть изменения playbook через Git.
