#!/bin/bash

# =================================================================
# Скрипт автоматического восстановления системы из бэкапа
# Версия 1.0
#
# ВНИМАНИЕ: Запускать на свежеустановленной системе Ubuntu
#           с правами sudo.
# =================================================================

# Останавливаем выполнение при любой ошибке
set -e

# --- Переменные ---
BACKUP_DISK_DEVICE="/dev/sdf1" # Устройство вашего бэкап-диска
BACKUP_MOUNT_POINT="/mnt/ufiles"
BACKUP_ROOT_DIR="$BACKUP_MOUNT_POINT/daily_backups"

# --- Функции ---
log() {
    echo ""
    echo "--- $1 ---"
    echo ""
}

# --- Начало скрипта ---

# 1. Проверка прав sudo
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Пожалуйста, запустите этот скрипт с правами sudo."
  exit 1
fi

log "Шаг 1: Установка необходимых утилит (rsync, dselect)"
apt-get update
apt-get install -y rsync dselect

log "Шаг 2: Монтирование диска с резервными копиями"
mkdir -p "$BACKUP_MOUNT_POINT"
if ! mount | grep -q "$BACKUP_MOUNT_POINT"; then
    mount "$BACKUP_DISK_DEVICE" "$BACKUP_MOUNT_POINT"
fi
echo "Диск $BACKUP_DISK_DEVICE смонтирован в $BACKUP_MOUNT_POINT"

# Проверка наличия файлов бэкапа
if [ ! -f "$BACKUP_ROOT_DIR/package.list" ]; then
    echo "Ошибка: Файлы бэкапа не найдены в $BACKUP_ROOT_DIR. Убедитесь, что диск подключен и содержит бэкапы."
    exit 1
fi

log "Шаг 3: Восстановление списка установленных пакетов"
dpkg --set-selections < "$BACKUP_ROOT_DIR/package.list"
apt-get dselect-upgrade -y
echo "Установка пакетов завершена."

log "Шаг 4: Восстановление системных конфигураций из /etc"
# Мы используем rsync с флагом --backup, чтобы не затереть критически важные новые файлы,
# а создать их резервные копии с символом '~' в конце.
rsync -av --backup --backup-dir="$BACKUP_MOUNT_POINT/etc_overwritten_$(date +%F)" "$BACKUP_ROOT_DIR/etc/" /etc/
echo "Файлы из /etc восстановлены."

log "Шаг 5: Восстановление домашней директории"
# Здесь мы полностью синхронизируем данные, так как это пользовательские файлы
rsync -av --delete "$BACKUP_ROOT_DIR/home/" /home/
echo "Домашняя директория восстановлена."

log_message "Шаг 6: Восстановление заданий cron для root"
# Перед восстановлением создаем резервную копию текущего crontab (если он есть)
crontab -l > "$BACKUP_ROOT_DIR/crontab_before_restore_$(date +%F).txt" || true
crontab "$BACKUP_ROOT_DIR/root_crontab.txt"
echo "Crontab для root восстановлен."

log "====== Восстановление системы успешно завершено! ======"
echo "Рекомендуется перезагрузить компьютер."

exit 0
