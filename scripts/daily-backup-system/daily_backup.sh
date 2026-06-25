#!/bin/bash

# Скрипт для ежедневного инкрементального бэкапа
# Версия 4: добавлены исключения для .docker
# --------------------------------------------------

# Останавливаем выполнение при любой ошибке
set -e

# --- Переменные ---
# Источники
SOURCE_HOME="/home/nsadmin"
SOURCE_ETC="/etc"

# Назначение
DEST_HOME="/mnt/ufiles/daily_backups/home/"
DEST_ETC="/mnt/ufiles/daily_backups/etc/"
DEST_ROOT_BACKUPS="/mnt/ufiles/daily_backups/"

# Лог-файл
LOG_FILE="/var/log/daily_backup.log"

# --- Функции ---
# Функция для логирования с временной меткой
log() {
    # Чистим лог-файл перед новым запуском, чтобы видеть только актуальные ошибки
    # При этом сохраняем предыдущий лог для истории
    [ -f "$LOG_FILE" ] && mv "$LOG_FILE" "$LOG_FILE.old"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# --- Начало скрипта ---
log "====== Начат ежедневный бэкап v4 ======"

# Бэкап домашней директории с исключениями
log "Синхронизация домашней директории: $SOURCE_HOME -> $DEST_HOME"
log "Исключаемые каталоги: 'snap/', '.cache/', '.docker/'"
rsync -av --delete \
      --exclude='snap/' \
      --exclude='.cache/' \
      --exclude='.docker/' \
      "$SOURCE_HOME/" "$DEST_HOME" >> "$LOG_FILE" 2>&1
log "Синхронизация домашней директории завершена."

# Бэкап /etc
log "Синхронизация /etc: $SOURCE_ETC -> $DEST_ETC"
rsync -av --delete "$SOURCE_ETC/" "$DEST_ETC" >> "$LOG_FILE" 2>&1
log "Синхронизация /etc завершена."

# Сохранение списка установленных пакетов
log "Сохранение списка установленных пакетов в $DEST_ROOT_BACKUPS/package.list"
dpkg --get-selections > "$DEST_ROOT_BACKUPS/package.list" 2>> "$LOG_FILE"
log "Список пакетов сохранен."

# Сохранение crontab пользователя root
log "Сохранение crontab пользователя root в $DEST_ROOT_BACKUPS/root_crontab.txt"
crontab -l > "$DEST_ROOT_BACKUPS/root_crontab.txt" 2>> "$LOG_FILE"
log "Crontab root сохранен."


log "====== Ежедневный бэкап v4 успешно завершен ======"
echo "" >> "$LOG_FILE" # Пустая строка для читаемости

exit 0