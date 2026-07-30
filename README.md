# Основной сервер OSNOVA IT / ZUER

Рабочая документация по администрированию сервера `ZUER`, публикации сервисов
домена `godny.tech`, хранению файлов через Nextcloud и воспроизводимому
управлению конфигурацией через Ansible.

## 1. Текущее состояние

| Параметр | Значение |
| --- | --- |
| Hostname | `ZUER` |
| ОС | Ubuntu 26.04 LTS |
| Основной пользователь | `nsadmin` |
| Рабочий каталог | `/run/media/nsadmin/godny_soft/soft/sysadmin` |
| LAN IP | `192.168.0.101` |
| Роутер | `192.168.0.1` |
| Публичный IPv4 | `85.172.104.173` |
| Публичный IPv6 | `2a13:7c00:10:26:f816:3eff:fe99:a89e` |
| Домен | `godny.tech` |
| Публичный сервис | `https://cloud.godny.tech` |
| Reverse proxy | Traefik через file provider |
| Nextcloud stack | `/opt/nextcloud` |
| Операционный реестр | `/srv/registry` |

Текущая публичная схема:

```text
Internet
  -> godny.tech / *.godny.tech
  -> 85.172.104.173
  -> router 80/443
  -> 192.168.0.101
  -> Traefik
  -> Nextcloud app container
```

## 2. Ключевые сервисы

| Сервис | URL / адрес | Назначение | Доступ |
| --- | --- | --- | --- |
| Nextcloud | `https://cloud.godny.tech` | веб-доступ к файлам | public HTTPS |
| Traefik dashboard | `https://traefik.godny.tech` | reverse proxy dashboard | HTTPS + Basic Auth |
| Nextcloud local | `http://127.0.0.1:18080` | локальная диагностика | localhost only |
| SSH | `ssh nsadmin@85.172.104.173` | администрирование | не менять без отдельного решения |
| XRDP | `3389/tcp` | удаленный рабочий стол | LAN/VPN/SSH tunnel only |

Проверка публикации:

```bash
curl --noproxy '*' -I https://cloud.godny.tech
curl --noproxy '*' -I https://traefik.godny.tech
sudo docker logs traefik --tail=50
```

Ожидаемо:

```text
cloud.godny.tech   -> HTTP/2 302, Location: /login
traefik.godny.tech -> HTTP/2 401, Basic Auth
```

## 3. Структура каталога

```text
sysadmin/
├── README.md
├── CODEX.md
├── REPORT.md
├── docs/
│   └── server-state.md
├── logs/
│   └── changelog.md
├── ansible.cfg
├── ansible/
│   ├── bootstrap.yml
│   ├── publish-web.yml
│   ├── inventory.ini
│   ├── group_vars/all.yml
│   ├── group_vars/vault.yml.example
│   ├── templates/
│   └── web/godny.tech.zone.txt
└── scripts/
```

Главные playbooks:

- `ansible/bootstrap.yml` - базовая подготовка хоста: пакеты, Docker, UFW,
  storage mounts, Nextcloud, XRDP, fail2ban, backup timer.
- `ansible/publish-web.yml` - публикация `godny.tech` через Traefik и
  обновление `/srv/registry`.
- `ansible/ssh-access.yml` - добавление SSH-ключей устройств и опциональный
  key-only hardening.
- `ansible/desktop-settings.yml` - воспроизводимые настройки GNOME, включая
  вставку выделенного текста средней кнопкой мыши.
- `ansible/desktop-bookmarks.yml` - добавление закладок storage-дисков в
  графический файловый менеджер.

## 4. Ansible runbooks

Все команды выполняются из корня этого каталога:

```bash
cd /run/media/nsadmin/godny_soft/soft/sysadmin
```

Базовая подготовка сервера:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/bootstrap.yml
```

Публикация web-слоя:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/publish-web.yml
```

SSH-доступ устройств:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml --check --diff --ask-vault-pass
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml --ask-vault-pass
```

`QwackPhone` уже добавлен как воспроизводимый public key в
`ansible/group_vars/all.yml` и проверен:

```text
Fingerprint: SHA256:5lbUW/d0SOFgp9gPRoWYbzdmLBaKYccbQl0U9vfe1dA
LAN SSH:     192.168.0.101:22
Public SSH:  85.172.104.173:22 -> router -> 192.168.0.101:22
```

После проверки входа с `qbook`, `QwackPhone`, `QwackPad`:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/ssh-access.yml \
  --ask-vault-pass \
  -e ssh_enable_key_only_hardening=true
```

GUI-закладки дисков:

```bash
ansible-playbook -i ansible/inventory.ini ansible/desktop-bookmarks.yml
```

Настройки GNOME можно проверить и применить отдельно от полного bootstrap:

```bash
sudo ansible-playbook -i ansible/inventory.ini ansible/desktop-settings.yml --check --diff
sudo ansible-playbook -i ansible/inventory.ini ansible/desktop-settings.yml
```

Playbook задаёт системное значение `gtk-enable-primary-paste=true`, обновляет
базу `dconf` и проверяет эффективное значение для пользователя `nsadmin`.

`publish-web.yml` делает только web-публикацию:

- проверяет host `ZUER` и IP `192.168.0.101`;
- проверяет DNS `godny.tech`, `cloud.godny.tech`, `traefik.godny.tech`;
- проверяет writable storage mountpoints;
- создает `/srv/proxy/traefik`;
- поднимает Traefik на `80/443`;
- публикует существующий `/opt/nextcloud`, не создавая второй Nextcloud;
- создает `/srv/registry/{domains,ports,services,server-notes}.md`;
- не удаляет Docker volumes и не меняет SSH.

## 5. Traefik

Traefik развернут в:

```text
/srv/proxy/traefik
```

Основные файлы:

```text
/srv/proxy/traefik/docker-compose.yml
/srv/proxy/traefik/.env
/srv/proxy/traefik/letsencrypt/acme.json
/srv/proxy/traefik/dynamic/routes.yml
/srv/proxy/traefik/dynamic/users.htpasswd
/srv/proxy/traefik/dynamic/dashboard-password.txt
```

Важные решения:

- маршруты задаются через file provider: `/dynamic/routes.yml`;
- Docker provider отключен, Docker socket в Traefik не монтируется;
- TLS выпускается через Let's Encrypt HTTP-01;
- `cloud.godny.tech` ведет на `http://nextcloud-app-1:80`;
- `traefik.godny.tech` защищен Basic Auth.

Пароль dashboard хранится root-only:

```bash
sudo cat /srv/proxy/traefik/dynamic/dashboard-password.txt
```

Проверка конфигурации:

```bash
cd /srv/proxy/traefik
sudo docker compose config
sudo docker compose ps
sudo docker logs traefik --tail=100
```

## 6. Nextcloud

Nextcloud установлен в:

```text
/opt/nextcloud
```

Основные файлы:

```text
/opt/nextcloud/docker-compose.yml
/opt/nextcloud/nextcloud.env
```

Контейнеры:

| Контейнер | Назначение | Публикация |
| --- | --- | --- |
| `nextcloud-app-1` | Nextcloud Apache/PHP | `127.0.0.1:18080` + Traefik |
| `nextcloud-db-1` | MariaDB | internal only |
| `nextcloud-redis-1` | Redis | internal only |

Внешние хранилища:

| Nextcloud mount | Container path | Host path |
| --- | --- | --- |
| `/x-files` | `/mnt/x-files` | `/srv/storage/x-files` |
| `/mega files` | `/mnt/mega-files` | `/srv/storage/mega-files` |
| `/godny soft` | `/mnt/godny-soft` | `/run/media/nsadmin/godny_soft` |

Проверки:

```bash
cd /opt/nextcloud
sudo docker compose ps
sudo docker compose exec -T -u www-data app php occ status
sudo docker compose exec -T -u www-data app php occ files_external:list
```

`godny_soft` добавляется тем же Ansible-механизмом, что и остальные external
storage, но монтируется в контейнер как read-only. Это сделано намеренно:
проектный диск принадлежит `nsadmin:nsadmin`, и давать Nextcloud запись в
рабочий проектный том небезопасно. Для `x-files` и `mega-files` по-прежнему
ожидается writable access.

## 7. Storage

| Назначение | Устройство | Метка | UUID | Mountpoint |
| --- | --- | --- | --- | --- |
| Бэкапы и данные | `/dev/sdf1` | `ufiles` | `548a00f5-dfd3-47d0-9879-b2a175b5bdb1` | `/mnt/ufiles` |
| Файлы | `/dev/sdd2` | `X-FILES` | `2800B35C00B33024` | `/srv/storage/x-files` |
| Файлы | `/dev/sde1` | `MEGA FILES` | `18B0DD66B0DD4AC0` | `/srv/storage/mega-files` |

Перед задачами Nextcloud writable storage должен быть `rw`:

```bash
findmnt -T /mnt/ufiles -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/x-files -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/mega-files -no TARGET,SOURCE,FSTYPE,OPTIONS
```

Если виден `ro`, не считать Nextcloud готовым. Сначала восстановить файловую
систему или исправить конфликт desktop/system mount.

### Почему x-files и mega-files не видны как диски в GUI

`x-files` и `mega-files` смонтированы как системные mountpoints:

```text
/srv/storage/x-files
/srv/storage/mega-files
```

GNOME Files/Nautilus обычно показывает в боковой панели пользовательские
udisks-mounts под `/run/media/<user>`, но не обязан показывать системные
mountpoints как отдельные “диски”. Для удобства используются bookmarks:

```text
file:///srv/storage/x-files x-files
file:///srv/storage/mega-files mega-files
file:///run/media/nsadmin/godny_soft godny_soft
```

Если bookmarks не добавляются из-за `Read-only file system`, сначала проверить:

```bash
findmnt -T /home/nsadmin -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/x-files -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /srv/storage/mega-files -no TARGET,SOURCE,FSTYPE,OPTIONS
findmnt -T /run/media/nsadmin/godny_soft -no TARGET,SOURCE,FSTYPE,OPTIONS
```

На production-хосте `x-files` и `mega-files` должны показывать `rw`.
`godny_soft` может оставаться read-only: в Nextcloud он публикуется именно так.

## 8. Firewall и публичные порты

Текущая политика UFW:

- default incoming: deny;
- default outgoing: allow;
- public web: `80/tcp`, `443/tcp`;
- SSH `22/tcp` уже разрешен и не менялся в рамках web-публикации;
- XRDP `3389/tcp` разрешен только из private-сетей;
- базы данных и Redis наружу не публикуются.

Проверка:

```bash
sudo ufw status verbose
sudo ss -tulpn | grep -E ':80|:443|:3306|:5432|:6379|:3389|:22'
sudo docker ps
```

Не открывать наружу без отдельного подтверждения:

```text
21 FTP
22 SSH policy changes
3306 MariaDB/MySQL
5432 PostgreSQL
6379 Redis
9000/9001 MinIO
3000/8000/8080 dev/internal web
3389 RDP public internet
```

## 9. DNS

Ожидаемые записи:

```text
godny.tech         A      85.172.104.173
www.godny.tech     A      85.172.104.173
*.godny.tech       A      85.172.104.173
godny.tech         MX     mx1.spaceweb.ru, mx2.spaceweb.ru
```

Проверка:

```bash
dig godny.tech A +short
dig www.godny.tech A +short
dig cloud.godny.tech A +short
dig traefik.godny.tech A +short
dig godny.tech MX +short
```

## 10. Операционный реестр

Фактическое состояние публикации фиксируется в:

```text
/srv/registry/domains.md
/srv/registry/ports.md
/srv/registry/services.md
/srv/registry/server-notes.md
```

Шаблоны этих файлов лежат в `ansible/templates/registry-*.j2` и обновляются
playbook'ом `ansible/publish-web.yml`.

## 11. Hiddify и исходящий трафик

Hiddify установлен как пользовательское приложение и может задавать proxy для
исходящих CLI-запросов. Для проверки публичных сервисов использовать
`--noproxy '*'`, иначе `curl` может идти через локальный proxy:

```bash
curl --noproxy '*' -I https://cloud.godny.tech
curl --noproxy '*' -I https://traefik.godny.tech
```

Hiddify не меняет системный default route. Входящие SSH/HTTP/HTTPS должны
оставаться через Ростелеком:

```text
default via 192.168.0.1 dev enp4s0
```

Для интерактивных shell/SSH-сессий `nsadmin` настроен user-level proxy:

```text
~/.config/hiddify/proxy-env
~/.bashrc
```

Если Hiddify слушает `127.0.0.1:12334`, новая интерактивная bash-сессия
автоматически получает:

```text
HTTP_PROXY=http://127.0.0.1:12334
HTTPS_PROXY=http://127.0.0.1:12334
ALL_PROXY=socks5h://127.0.0.1:12334
NO_PROXY=localhost,127.0.0.0/8,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,85.172.104.173,.godny.tech
```

Команды управления в shell:

```bash
vpn-proxy-check
vpn-proxy-on
vpn-proxy-off
```

Ожидаемая проверка:

```text
direct: 85.172.104.173
proxy:  94.183.234.153
```

Не менять default route, TUN или policy routing без отдельного плана и rollback.

## 12. Проекты на диске

Известные проектные корни:

| Проект | Путь | Комментарий |
| --- | --- | --- |
| GigaVPN | `/run/media/nsadmin/godny_soft/soft/gigavpn` | Go/Python/PostgreSQL/VPN control plane |
| Kolos Web | `/run/media/nsadmin/godny_soft/soft/kolos_web` | Strapi/PostgreSQL/Next.js |
| Anaconda Site | `/run/media/nsadmin/godny_soft/site/anaconda_site` | Vite/React |
| Anaconda MVP | `/run/media/nsadmin/godny_soft/soft/kip-service/anaconda_mvp` | FastAPI/Vue/PostgreSQL |
| Black Mamba | `/run/media/nsadmin/godny_soft/soft/black_mamba` | локальная LLM/RAG-платформа |
| DevOps Lab | `/run/media/nsadmin/godny_soft/soft/devops-lab` | lab/observability |
| Codex Node Agent | `/run/media/nsadmin/godny_soft/soft/codex_node_agent` | ранний automation service |

Перед публикацией любого проекта:

- проверить exposed/published ports;
- заменить demo/default credentials;
- не публиковать базы и Redis;
- добавить healthcheck/logs;
- определить backup strategy;
- добавить домен и порт в `/srv/registry`.

## 13. GitHub

На сервере используются два GitHub-аккаунта с раздельными SSH-ключами:

| Аккаунт | SSH alias | Ключ | Назначение |
| --- | --- | --- | --- |
| `GodnySoft` | `github-godnysoft` | `~/.ssh/github_godnysoft_ed25519` | рабочие репозитории GodnySoft |
| `Nepomnyashiy` | `github-nepomnyashiy` | `~/.ssh/github_nepomnyashiy_ed25519` | личные репозитории |

Публичные ключи добавлены в GitHub. Приватные ключи не копировать в Markdown,
репозитории, задачи или логи.

Проверка доступа:

```bash
ssh -T git@github-godnysoft
ssh -T git@github-nepomnyashiy
```

Ожидаемый ответ GitHub содержит успешную аутентификацию и фразу о том, что
shell access не предоставляется.

Для репозиториев использовать alias в remote URL, чтобы Git выбирал правильный
ключ:

```bash
git remote set-url origin git@github-godnysoft:GodnySoft/kolos_web.git
```

Текущее состояние `kolos_web`:

```text
Path:   /run/media/nsadmin/godny_soft/soft/kolos_web
Remote: git@github-godnysoft:GodnySoft/kolos_web.git
Branch: main
Latest synced commit: 9219e48 Release v1.1.0 order workflow and ZUER bootstrap
Tag: v1.1.0
```

При обновлении `kolos_web` сначала проверить локальные изменения:

```bash
git -C /run/media/nsadmin/godny_soft/soft/kolos_web status --short --branch
```

Если пользователь явно разрешил перезаписать локальные изменения:

```bash
git -C /run/media/nsadmin/godny_soft/soft/kolos_web fetch --prune origin
git -C /run/media/nsadmin/godny_soft/soft/kolos_web reset --hard origin/main
git -C /run/media/nsadmin/godny_soft/soft/kolos_web clean -fd
```

Без явного разрешения не выполнять `reset --hard` и `clean -fd`.

## 14. Резервное копирование

Системный backup управляется:

```text
osnova-backup.timer
osnova-backup.service
/usr/local/sbin/osnova-backup.sh
```

Проверка:

```bash
systemctl list-timers osnova-backup.timer
systemctl status osnova-backup.timer
sudo journalctl -u osnova-backup.service -n 100 --no-pager
```

## 15. Журналы и аудит

Основные документы:

```text
docs/server-state.md
docs/ssh-devices.md
logs/changelog.md
REPORT.md
CODEX.md
```

После инфраструктурных изменений обновлять минимум:

- `docs/server-state.md` - фактическое состояние сервера;
- `logs/changelog.md` - что изменено и почему;
- `/srv/registry/*` - публичные домены, порты и сервисы.

## 16. Жесткие правила

- Не форматировать диски без явного подтверждения exact device и backup status.
- Не удалять Docker volumes, project data, базы и `.env` без подтверждения.
- Не отключать UFW.
- Не открывать наружу базы данных, Redis, Grafana, Prometheus, pgAdmin,
  cAdvisor, MinIO API/console, FTP и RDP.
- Не менять SSH policy без отдельного подтверждения.
- Не включать Hiddify/TUN/default route автоматически.
- Не хранить секреты в git или открытых Markdown-файлах.

## 17. Следующие действия

1. Проверить `https://cloud.godny.tech` с мобильного интернета.
2. Сохранить Traefik dashboard password в менеджер паролей.
3. Добавить SSH-ключи `qbook` и `QwackPad`.
4. После проверки входа со всех устройств включить key-only SSH hardening.
5. Переименовать 15 файлов в `mega-files` с несовместимой кодировкой имен.
6. Ротировать секреты `/opt/nextcloud/nextcloud.env`, если они попадали в вывод
   диагностики.
7. Добавить внешний backup слой: Restic/Borg repository вне этого сервера.
