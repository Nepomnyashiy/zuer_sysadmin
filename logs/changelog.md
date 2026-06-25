# Журнал изменений (Changelog)

---

## Запись #14: SSH-устройства и подготовка `godny_soft` для Nextcloud

- **Дата:** 25.06.2026
- **Инициатор:** `nsadmin`
- **Задача:** Подготовить безопасный SSH-доступ для `qbook`,
  `QwackPhone`, `QwackPad`; добавить `godny_soft` в Nextcloud по модели
  external storage; разобраться, почему `x-files` и `mega-files` не видны в
  графическом файловом проводнике.

### Решение

1. Добавлен `ansible/ssh-access.yml`.
2. Добавлен документ `docs/ssh-devices.md` с инструкцией генерации Ed25519-ключа
   на Ubuntu и настройкой Termius/Blink.
3. В `ansible/group_vars/all.yml` добавлены:
   - `ssh_authorized_devices`
   - `ssh_enable_key_only_hardening`
   - `godny_soft_mount`
   - `nextcloud_external_storages`
4. `ansible/templates/nextcloud-compose.yml.j2` переведен на список external
   storage volumes.
5. `ansible/bootstrap.yml` теперь создает, проверяет и сканирует external
   storage списком, включая `godny soft`.
6. Добавлен `ansible/desktop-bookmarks.yml` для GTK bookmarks:
   `x-files`, `mega-files`, `godny_soft`.
7. Обновлены `README.md`, `ansible/README.md`, `docs/server-state.md`.

### Диагностика

В execution-среде агента mount pre-check показал `ro` для `/`,
`/run/media/nsadmin/godny_soft`, `/mnt/ufiles`, `/srv/storage/x-files` и
`/srv/storage/mega-files`. Попытка применить bookmarks остановилась с
`Read-only file system` для `/home/nsadmin/.config/gtk-3.0`.

Перед фактическим применением storage-части на реальном хосте нужно проверить:

```bash
findmnt -T /home/nsadmin -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /run/media/nsadmin/godny_soft -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /mnt/ufiles -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/x-files -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/mega-files -no TARGET,SOURCE,FSTYPE,OPTIONS
```

### Итог

- SSH-доступ подготовлен как воспроизводимый Ansible-runbook.
- `godny_soft` подготовлен в Nextcloud compose/bootstrap как третий external
  storage и публикуется в контейнер read-only.
- GUI-видимость решается bookmarks, без переноса серверных mountpoints.
- Фактическое применение storage-части должно остановиться, если writable
  mountpoints (`x-files`, `mega-files`) остаются `ro`.

---

## Запись #13: Публикация Nextcloud через Traefik на `godny.tech`

- **Дата:** 25.06.2026
- **Инициатор:** `nsadmin`
- **Задача:** Опубликовать существующий Nextcloud в интернет через
  `cloud.godny.tech`, поднять Traefik на `80/443`, выпустить TLS-сертификаты
  Let's Encrypt и зафиксировать состояние в документации.

### Исходные вводные

1. Сервер: `ZUER`, LAN IP `192.168.0.101`.
2. Public IPv4: `85.172.104.173`.
3. Роутер уже пробрасывает `80/tcp` и `443/tcp` на сервер.
4. DNS `godny.tech`, `www`, wildcard, `cloud.godny.tech` и
   `traefik.godny.tech` указывают на `85.172.104.173`.
5. Nextcloud уже существовал в `/opt/nextcloud`; новый стек создавать было
   небезопасно из-за данных, volumes и секретов.

### Решение

1. Добавлен focused playbook `ansible/publish-web.yml`.
2. Создан Traefik stack в `/srv/proxy/traefik`.
3. Существующий Nextcloud подключен к Docker-сети `proxy`.
4. Публикация выполнена через Traefik file provider:
   `/srv/proxy/traefik/dynamic/routes.yml`.
5. Docker provider Traefik отключен из-за ошибки совместимости Docker API:

```text
client version 1.24 is too old. Minimum supported API version is 1.44
```

6. Docker socket больше не монтируется в Traefik.
7. Выпущены сертификаты Let's Encrypt для:
   - `cloud.godny.tech`
   - `traefik.godny.tech`
8. Dashboard Traefik защищен Basic Auth.
9. Созданы шаблоны registry-файлов для `/srv/registry`.
10. Обновлен `README.md` и `docs/server-state.md`.

### Итоговые проверки

```text
curl --noproxy '*' -I https://cloud.godny.tech
HTTP/2 302
location: https://cloud.godny.tech/login
```

```text
curl --noproxy '*' -I https://traefik.godny.tech
HTTP/2 401
www-authenticate: Basic realm="traefik"
```

Traefik access log:

```text
"nextcloud@file" "http://nextcloud-app-1:80"
```

### Безопасность

- MariaDB и Redis наружу не опубликованы.
- `80/tcp` и `443/tcp` обслуживаются Traefik.
- Существующие правила SSH `22/tcp` не менялись.
- RDP остается только для private-сетей.
- Docker volumes не удалялись.

### Использованные команды

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml
curl --noproxy '*' -I https://cloud.godny.tech
curl --noproxy '*' -I https://traefik.godny.tech
sudo docker logs traefik --tail=50
```

Подробности: `docs/server-state.md`.

---

## Запись #12: Восстановление Nextcloud external storage и фиксация состояния

- **Дата:** 25.06.2026
- **Инициатор:** `nsadmin`
- **Задача:** Найти причину, почему диски `x-files` и `mega files` не показывали
  файлы в Nextcloud Web, исправить монтирование/доступы и закрепить состояние в
  Ansible.

### Проблема

1. `mega-files` периодически монтировался read-only.
2. Nextcloud external storage сначала не имел admin mounts.
3. После создания mounts веб-интерфейс показывал пустые каталоги, потому что
   существующие файлы не были просканированы в файловый кеш Nextcloud.
4. В ходе диагностики были временно созданы дубли external storage.

### Решение

1. Пользователь `nsadmin` добавлен в группу `docker`.
2. `mega-files` восстановлен через `ntfsfix -d` и повторное монтирование.
3. В Nextcloud оставлены только две external storage записи:
   `/x-files` и `/mega files`.
4. Выполнено `occ files:scan` для `/admin/files/x-files` и
   `/admin/files/mega files`.
5. В `ansible/bootstrap.yml` усилены проверки storage:
   check-mode диагностика `findmnt`/`mountpoint`, token-based `ro/rw` проверки,
   запись внутри контейнера перед настройкой external storage, assert наличия
   mount points.
6. В `ansible/group_vars/all.yml` добавлена переменная
   `nextcloud_external_storage_scan_enabled`.
7. Создан журнал состояния `docs/server-state.md`.

### Итог

- `/srv/storage/x-files` и `/srv/storage/mega-files` смонтированы `rw`.
- Nextcloud 34.0.0 работает, `maintenance=false`, `needsDbUpgrade=false`.
- `x-files`: 4418 папок, 36761 файлов, 0 ошибок scan.
- `mega files`: 4034 папки, 91997 файлов, 15 ошибок несовместимой кодировки
  имён.

### Использованные команды

```bash
sudo usermod -aG docker nsadmin
sudo docker compose -f /opt/nextcloud/docker-compose.yml down
sudo ntfsfix -d /dev/disk/by-uuid/18B0DD66B0DD4AC0
sudo mount /srv/storage/mega-files
docker exec -u www-data nextcloud-app-1 php occ files_external:list
docker exec -u www-data nextcloud-app-1 php occ files:scan --path=/admin/files/x-files
docker exec -u www-data nextcloud-app-1 php occ files:scan --path=/admin/files/'mega files'
```

Подробности: `docs/server-state.md`.

---

## Запись #11: Размещение конфигурационного файла msmtp в проекте

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Сохранить исправленный конфигурационный файл msmtp в структуре проекта для удобства.

### Решение

1.  Создана директория `msmtprc` в корне проекта.
2.  Исправленный конфигурационный файл `msmtprc.conf` (с правильным адресом отправителя и отключенным `tls_starttls`) помещен в эту директорию.

### Использованные команды

```bash
mkdir -p msmtprc
# mv msmtprc.new msmtprc/msmtprc.conf
# (Файл msmtprc.new был воссоздан и перемещен)
```

---

## Запись #10: Настройка отправки почты через msmtp (устранение ошибки)

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Настроить отправку почты с ПК для системных уведомлений через Mail.ru.

### Проблема

1.  Исходный конфигурационный файл `msmtprc` для Mail.ru содержал конфликт настроек TLS (`port 465` с `tls_starttls on`), что приводило к зависанию при попытке отправки письма.

### Решение

1.  Установлены пакеты `msmtp` и `msmtp-mta`.
2.  Файл `msmtprc` был скорректирован: для аккаунта Mail.ru (`host smtp.mail.ru`, `port 465`) параметр `tls_starttls` был установлен в `off`, так как порт 465 использует неявное (implicit) TLS.
3.  Настройки обновлены с использованием правильного адреса отправителя `nep.s.a@mail.ru`.

### Использованные команды

```bash
# Установка msmtp
sudo apt-get update && sudo apt-get install -y msmtp msmtp-mta

# Создание и перемещение конфигурационного файла
# (подробные команды см. в предыдущих шагах)

# Пример тестовой отправки
echo -e "Subject: Тестовое письмо от вашего ПК\n\nЭто тестовое сообщение от вашего ПК." | msmtp -d ваш_адрес@example.com
```

---

## Запись #9: Создание постоянных алиасов для управления бэкапами

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Создать удобные алиасы для ручного запуска бэкапа и просмотра его логов.

### Решение

1.  Создан алиас `make-bckp-now` для запуска скрипта ежедневного бэкапа (`sudo /usr/local/bin/daily_backup.sh`).
2.  Создан алиас `bckp-logs` для просмотра лога выполнения бэкапов (`tail -f /var/log/daily_backup.log`).
3.  Оба алиаса добавлены в файл `~/.bash_aliases` для постоянного использования в оболочке Bash.

### Использованные команды

```bash
# Добавление алиаса make-bckp-now
echo "alias make-bckp-now='sudo /usr/local/bin/daily_backup.sh'" >> ~/.bash_aliases

# Добавление алиаса bckp-logs
echo "alias bckp-logs='tail -f /var/log/daily_backup.log'" >> ~/.bash_aliases

# Применение изменений в текущей сессии
source ~/.bashrc
```

---

## Запись #8: Настройка автоматического подключения WireGuard VPN

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Настроить WireGuard VPN-соединение на автоматическое подключение при старте системы.

### Решение

1.  Определено, что WireGuard VPN управляется NetworkManager под именем соединения `ZUER`.
2.  С помощью `nmcli` настроено автоматическое подключение этого соединения при загрузке системы.

### Использованные команды

```bash
# Проверка активных соединений NetworkManager
nmcli connection show --active

# Включение автоматического подключения для VPN-соединения ZUER
sudo nmcli connection modify ZUER connection.autoconnect yes

# Проверка статуса автоподключения
nmcli connection show ZUER | grep autoconnect
```

---

## Запись #7: Завершение развертывания системы резервного копирования

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Зафиксировать завершение развертывания локальной системы резервного копирования и её документации.

### Решение

1.  Успешно настроена система ежедневного инкрементального резервного копирования на локальный диск (`ufiles`).
2.  Разработан скрипт `daily_backup.sh`, который копирует домашний каталог, системные конфигурации (`/etc`), список установленных пакетов и `crontab` пользователя `root`.
3.  Настроено автоматическое выполнение бэкапа через `cron`.
4.  Создан скрипт `recovery.sh` для автоматизированного восстановления системы с нуля.
5.  Все скрипты и подробные инструкции по развертыванию и восстановлению объединены в директории `scripts/daily-backup-system/` с файлом `README.md`.
6.  Лог выполнения бэкапов доступен по символической ссылке `logs/daily_backup.log`.

### Использованные команды

```bash
# См. предыдущие записи в Changelog
```

---

## Запись #6: Организация файлов и документация системы бэкапа

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Сгруппировать все скрипты по бэкапу и восстановлению в отдельной директории и создать инструкцию по их развертыванию.

### Решение

1.  Создана директория `scripts/daily-backup-system/` для хранения всех скриптов, относящихся к системе резервного копирования.
2.  Скрипты `daily_backup.sh` (для ежедневного бэкапа) и `recovery.sh` (для восстановления системы) были размещены в этой директории.
3.  Создан файл `README.md` внутри `scripts/daily-backup-system/`, содержащий подробные инструкции по развертыванию системы бэкапа с нуля и шаги по восстановлению.

### Использованные команды

```bash
# Создание директории
mkdir -p scripts/daily-backup-system

# Запись скрипта daily_backup.sh в новую директорию
# (содержимое скрипта см. в Записи #3)

# Запись скрипта recovery.sh в новую директорию
# (содержимое скрипта см. в Записи #5)

# Запись инструкции README.md в новую директорию
# (содержимое README.md см. в предыдущих сообщениях)
```

---

## Запись #5: Создание скрипта автоматического восстановления

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Создать скрипт `recovery.sh` для автоматизации процесса восстановления системы из бэкапа на свежеустановленной ОС.

### Решение

1.  **Создан скрипт `recovery.sh`**, который автоматизирует следующие шаги:
    *   Проверка прав `sudo`.
    *   Установка `rsync`.
    *   Монтирование диска с бэкапами.
    *   Восстановление списка установленных пакетов с помощью `dpkg --set-selections` и `apt-get dselect-upgrade`.
    *   Восстановление системных конфигураций (`/etc`) и домашней директории (`/home`) с помощью `rsync`.
    *   Восстановление заданий `cron` для пользователя `root`.
2.  Скрипт предназначен для запуска на новой системе для быстрого восстановления после сбоя.

### Использованные команды

```bash
# Команда для создания скрипта recovery.sh
# (содержимое скрипта см. в предыдущих сообщениях)
touch recovery.sh
```

---

## Запись #4: Создание символической ссылки для лога бэкапа

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Создать символическую ссылку на лог-файл ежедневного бэкапа для удобного доступа и мониторинга из рабочей директории.

### Решение

1. Создана символическая ссылка `logs/daily_backup.log` в текущей рабочей директории, указывающая на файл `/var/log/daily_backup.log`. Это позволяет агенту напрямую просматривать лог бэкапа.

### Использованные команды

```bash
ln -s /var/log/daily_backup.log logs/daily_backup.log
```

---

## Запись #3: Настройка ежедневного резервного копирования

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Настроить автоматическое ежедневное резервное копирование домашнего каталога (`/home/nsadmin`) и системных конфигураций (`/etc`).

### Решение

1.  **Подготовка диска:** Диск `ufiles` был отформатирован в `ext4`, но не смонтирован. Была создана точка монтирования `/mnt/ufiles`, и диск был смонтирован. Для автоматического монтирования при загрузке системы была добавлена соответствующая запись в `/etc/fstab` с использованием UUID диска.

2.  **Структура бэкапов:** На диске `/mnt/ufiles/daily_backups/` были созданы поддиректории `home` и `etc` для организованного хранения резервных копий.

3.  **Скрипт резервного копирования:** Был создан bash-скрипт `/usr/local/bin/daily_backup.sh`. Скрипт использует `rsync` для выполнения инкрементального бэкапа и записывает подробный лог выполнения в `/var/log/daily_backup.log`.

4.  **Автоматизация:** С помощью `crontab` для пользователя `root` было добавлено задание для автоматического запуска скрипта резервного копирования каждую ночь в 02:30.

### Использованные команды

```bash
# Создание точки монтирования
sudo mkdir -p /mnt/ufiles

# Монтирование диска
sudo mount /dev/sdf1 /mnt/ufiles

# Получение UUID диска
sudo blkid -s UUID -o value /dev/sdf1

# Добавление записи в /etc/fstab (после предоставления пользователем содержимого)
# Пример добавленной строки:
# UUID=548a00f5-dfd3-47d0-9879-b2a175b5bdb1 /mnt/ufiles ext4 defaults 0 2

# Проверка монтирования
sudo mount -a
df -h /mnt/ufiles

# Создание структуры для бэкапов
sudo mkdir -p /mnt/ufiles/daily_backups/home
sudo mkdir -p /mnt/ufiles/daily_backups/etc

# Перемещение и настройка прав для скрипта
sudo mv daily_backup.sh /usr/local/bin/daily_backup.sh
sudo chmod +x /usr/local/bin/daily_backup.sh

# Настройка cron
sudo crontab -e
# Добавлена строка: 30 2 * * * /usr/local/bin/daily_backup.sh
```

---

## Запись #1: Настройка и защита SSH-сервера

- **Дата:** 20.11.2025
- **Инициатор:** `nsadmin`
- **Задача:** Настроить SSH-сервер для удаленного доступа и повысить его безопасность.

### Проблема

1.  При попытке подключения через Termius возникала ошибка `Connection refused`.
2.  Анализ показал, что сервис `sshd` продолжал работать на стандартном порту `22`, несмотря на изменения в `/etc/ssh/sshd_config`, из-за сокет-активации `systemd`.

### Решение

1.  **Установка и базовая настройка:**
    - Проверен статус сервиса `sshd`. Сервер уже был установлен и запущен.
    - Пользователю был предоставлен его локальный IP-адрес (`192.168.0.12`).

2.  **Усиление безопасности:**
    - Был создан новый конфигурационный файл `sshd_config.new` с двумя ключевыми изменениями:
        - `PermitRootLogin no` (отключение входа для суперпользователя).
        - `Port 2222` (смена стандартного порта).

3.  **Применение конфигурации:**
    - Старый конфигурационный файл был заменен новым.
    - Для корректного применения нового порта (из-за сокет-активации) были выполнены команды для перезагрузки `systemd` и перезапуска сокета `ssh`.

### Использованные команды

```bash
# 1. Проверка статуса SSH
systemctl status sshd

# 2. Получение IP-адреса
hostname -I | awk '{print $1}'

# 3. Замена файла конфигурации
sudo mv /home/nsadmin/portfolio/sysadmin/sshd_config.new /etc/ssh/sshd_config

# 4. Проверка порта, на котором работает SSH (до исправления)
sudo ss -tlpn | grep sshd
# Вывод показал порт 22

# 5. Исправление проблемы с сокет-активацией systemd
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket ssh.service

# 6. Повторная проверка порта (после исправления)
sudo ss -tlpn | grep sshd
# Вывод показал порт 2222
```

---
