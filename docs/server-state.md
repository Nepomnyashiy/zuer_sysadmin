# Журнал состояния сервера

## 2026-06-25: публикация `cloud.godny.tech` через Traefik

### Контекст

- Хост: `ZUER`
- LAN IP: `192.168.0.101`
- Public IPv4: `85.172.104.173`
- Домен: `godny.tech`
- Рабочий каталог администрирования:
  `/run/media/nsadmin/godny_soft/soft/sysadmin`
- Reverse proxy: Traefik, проект `/srv/proxy/traefik`
- Nextcloud: существующий Docker Compose stack `/opt/nextcloud`

### Цель

Опубликовать существующий Nextcloud в интернет как
`https://cloud.godny.tech` через Traefik и оставить наружу только web-порты
`80/tcp` и `443/tcp`.

### Реализованная схема

```text
Internet
  -> cloud.godny.tech / traefik.godny.tech
  -> 85.172.104.173
  -> router 80/443
  -> 192.168.0.101
  -> Traefik
  -> nextcloud-app-1:80
```

### DNS

Подтверждено:

```text
godny.tech          A 85.172.104.173
www.godny.tech      A 85.172.104.173
cloud.godny.tech    A 85.172.104.173
traefik.godny.tech  A 85.172.104.173
godny.tech          MX mx1.spaceweb.ru / mx2.spaceweb.ru
```

### Traefik

- Traefik развернут в `/srv/proxy/traefik`.
- TLS: Let's Encrypt HTTP-01.
- Docker provider отключен.
- Docker socket в Traefik не монтируется.
- Роутинг задан через file provider:
  `/srv/proxy/traefik/dynamic/routes.yml`.
- Dashboard: `https://traefik.godny.tech`, Basic Auth.
- Пароль dashboard хранится root-only:
  `/srv/proxy/traefik/dynamic/dashboard-password.txt`.

Причина отключения Docker provider:

```text
Error response from daemon: client version 1.24 is too old.
Minimum supported API version is 1.44
```

Маршруты через file provider работают стабильно и уменьшают доступ Traefik к
Docker daemon.

### Nextcloud

- Используется существующий stack `/opt/nextcloud`.
- Новый stack `/srv/projects/nextcloud` не создавался, чтобы не дублировать
  данные, volumes и секреты.
- `nextcloud-app-1` подключен к сети `proxy`.
- Traefik проксирует `cloud.godny.tech` на `http://nextcloud-app-1:80`.
- Локальный диагностический bind сохранен:
  `127.0.0.1:18080 -> 80/tcp`.
- MariaDB и Redis наружу не опубликованы.

### Проверки

```text
curl --noproxy '*' -I https://cloud.godny.tech
HTTP/2 302
location: https://cloud.godny.tech/login
strict-transport-security: max-age=15552000; includeSubDomains; preload
```

```text
curl --noproxy '*' -I https://traefik.godny.tech
HTTP/2 401
www-authenticate: Basic realm="traefik"
```

Логи Traefik показывают маршрутизацию:

```text
"nextcloud@file" "http://nextcloud-app-1:80"
```

### Firewall

UFW активен:

```text
default incoming: deny
default outgoing: allow
80/tcp: allow
443/tcp: allow
22/tcp: allow, существующее правило
3389/tcp: allow только private networks
```

SSH-правила не менялись в рамках публикации web-слоя.

### Изменения в Ansible

- Добавлен `ansible/publish-web.yml`.
- Добавлены шаблоны:
  - `ansible/templates/traefik-compose.yml.j2`
  - `ansible/templates/traefik-routes.yml.j2`
  - `ansible/templates/traefik.env.j2`
  - `ansible/templates/registry-*.j2`
- Обновлен `ansible/templates/nextcloud-compose.yml.j2`:
  Nextcloud app подключается к сети `proxy`, но маршруты Traefik задаются через
  file provider.
- Обновлены `ansible.cfg` и `ansible/ansible.cfg`: временные каталоги Ansible
  перенесены в `/tmp/ansible-*-nsadmin`, чтобы не конфликтовать с существующим
  `/tmp/ansible-remote`.
- Обновлен `README.md`.

### Команды контроля

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml
curl --noproxy '*' -I https://cloud.godny.tech
curl --noproxy '*' -I https://traefik.godny.tech
sudo docker logs traefik --tail=50
sudo ufw status verbose
```

### Оставшиеся действия

- Проверить `https://cloud.godny.tech` с мобильного интернета.
- Сохранить Traefik dashboard password в менеджер паролей.
- Отдельно решить политику публичного SSH: оставить `22/tcp` как есть или
  закрыть на роутере после настройки ключевого доступа/VPN.

## 2026-06-25: восстановление видимости дисков Nextcloud

### Контекст

- Хост: `ZUER`
- Рабочий каталог администрирования:
  `/run/media/nsadmin/godny_soft/soft/sysadmin`
- Nextcloud: Docker Compose, проект `/opt/nextcloud`
- Внешние файловые хранилища:
  - `/srv/storage/x-files` -> `/mnt/x-files` внутри контейнера
  - `/srv/storage/mega-files` -> `/mnt/mega-files` внутри контейнера

### Симптомы

- Диски появились в Nextcloud Web, но отображались пустыми.
- До этого `mega-files` периодически монтировался read-only.
- `occ files_external:list` сначала показывал отсутствие admin mounts, затем
  были созданы дубли external storage.

### Найденные причины

1. `mega-files` был смонтирован в `ro`, поэтому запись из контейнера была
   невозможна.
2. External storage mounts не были созданы в Nextcloud до ручного включения
   `files_external`.
3. После создания mounts существующие файлы на дисках не были просканированы
   в файловый кеш Nextcloud (`oc_filecache`), поэтому веб-интерфейс показывал
   пустые каталоги.
4. В `mega-files` обнаружены 15 файлов с несовместимой кодировкой имён. Эти
   отдельные файлы не будут доступны в Nextcloud до переименования в корректный
   UTF-8.

### Исправления

- Пользователь `nsadmin` добавлен в группу `docker`; Docker доступен без `sudo`
  для новых login-сессий.
- `mega-files` восстановлен через `ntfsfix -d` и повторное монтирование.
- Nextcloud external storage приведён к двум mount entries:
  - `/x-files` -> `/mnt/x-files`
  - `/mega files` -> `/mnt/mega-files`
- Дубли external storage с mount IDs `3` и `4` удалены.
- Выполнено сканирование файлового кеша:
  - `/admin/files/x-files`: `4418` папок, `36761` файлов, `0` ошибок
  - `/admin/files/mega files`: `4034` папки, `91997` файлов, `15` ошибок
    кодировки
- Тестовые `.nc-write-test` файлы удалены.

### Текущее подтверждённое состояние

```text
/srv/storage/x-files     /dev/sdd2 fuseblk rw
/srv/storage/mega-files  /dev/sde1 fuseblk rw
```

```text
Nextcloud external storage:
1 /x-files    datadir: /mnt/x-files
2 /mega files datadir: /mnt/mega-files
```

```text
Nextcloud 34.0.0:
installed: true
maintenance: false
needsDbUpgrade: false
```

### Изменения в Ansible

- Storage-проверки `findmnt`/`mountpoint` теперь выполняются и в check-mode,
  потому что они только читают состояние.
- Read-only проверки mount options сравнивают отдельные tokens (`ro`, `rw`), а
  не подстроки внутри всей строки options.
- Перед настройкой external storage playbook проверяет реальную запись внутри
  контейнера через `touch`/`rm`.
- После настройки external storage playbook assert'ит наличие `/x-files` и
  `/mega files`.
- Добавлена переменная:

```yaml
nextcloud_external_storage_scan_enabled: false
```

При необходимости разового scan:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml \
  -e nextcloud_external_storage_scan_enabled=true
```

### Команды контроля

```bash
findmnt -T /srv/storage/x-files -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/mega-files -no TARGET,SOURCE,FSTYPE,OPTIONS
docker exec -u www-data nextcloud-app-1 php occ files_external:list
docker exec -u www-data nextcloud-app-1 php occ status
```

### Оставшиеся действия

- Переименовать 15 файлов в `mega-files`, для которых Nextcloud сообщил
  `incompatible encoding`.
- Ротировать секреты `/opt/nextcloud/nextcloud.env`, так как значения были
  выведены через `docker compose config` в ходе диагностики.
- После перелогина проверить:

```bash
id
docker ps
```
