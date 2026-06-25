#!/bin/bash

# Создаем каталог для хранения информации
mkdir -p ./hostinfo

# Основное время выполнения
echo "Сбор данных о системе..."

# Информация о процессоре
CPU_INFO=$(lscpu | head -n 5)
echo "$CPU_INFO" > ./hostinfo/cpu_info.txt

# Данные о памяти
MEM_INFO=$(free -h)
echo "$MEM_INFO" > ./hostinfo/memory_usage.txt

# Сведения о дисках и файловых системах
DISK_INFO=$(lsblk)
echo "$DISK_INFO" > ./hostinfo/disk_info.txt

# Сетевая конфигурация
NETWORK_INFO=$(ip a; route -n)
echo "$NETWORK_INFO" > ./hostinfo/network_config.txt

# Текущие пользователи системы
USERS_INFO=$(who | cut -d' ' -f1 | sort | uniq)
echo "$USERS_INFO" > ./hostinfo/current_users.txt

# Установленные пакеты
PACKAGES_INFO=$(dpkg --get-selections | grep -v deinstall)
echo "$PACKAGES_INFO" > ./hostinfo/installed_packages.txt

# Создаем сводный отчет в стиле матрицы
echo "Отчет о системе $(hostname) на $(date +"%F %T")" > ./hostinfo/system_report.txt
echo "|----------------------------------------------------------------------------------|" >> ./hostinfo/system_report.txt
echo "| CPU Information: $(lscpu | head -n 1)" >> ./hostinfo/system_report.txt
echo "| Memory Usage: $(free -h | head -n 2 | tail -n 1)" >> ./hostinfo/system_report.txt
echo "| Disk Usage: $(lsblk | head -n 3 | tail -n 1)" >> ./hostinfo/system_report.txt
echo "| Network Status: $(ip a | head -n 3 | tail -n 1)" >> ./hostinfo/system_report.txt
echo "| Users Online: $(who | wc -l) users" >> ./hostinfo/system_report.txt

# Завершение работы скрипта
echo "Информация успешно сохранена в каталоге ./hostinfo"