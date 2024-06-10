#!/bin/bash

# Параметры подключения к арбитру
ARBITER_HOST="192.168.111.144"
ARBITER_PORT="5433"

# Параметры подключения к мастеру
MASTER_HOST="192.168.111.139"
MASTER_PORT="5432"

# Лог файл
LOG_FILE="/var/log/postgresql/failover.log"

#Проверка промоута реплики
CHECK_STANDBY_PROMOTING=$(cat /usr/local/bin/check_standby_promoting.txt)

# Функция проверки доступности арбитра
check_arbiter() {
    nc -z "$ARBITER_HOST" "$ARBITER_PORT"
    return $?
}

# Функция проверки доступности мастера
check_master() {
    pg_isready -h "$MASTER_HOST" -p "$MASTER_PORT"
    return $?
}

# Функция проверки состояния мастера через арбитра
check_master_via_arbiter() {
    stat=$(nc $ARBITER_HOST $ARBITER_PORT)
    if [[ $stat == *"Master down"* ]]; then
        return 1
    else
        return 0
    fi
}

# Функция продвижения реплики до мастера
promote_standby() {
    pg_ctlcluster 16 main promote
    echo "$(date): Promoted standby to master" >> $LOG_FILE
    # Установим значение пользовательской переменной в true после выполнения трансформации
    echo true > /usr/local/bin/check_standby_promoting.txt
}

# Основной блок
if check_arbiter && ! check_master && ! check_master_via_arbiter && ! $CHECK_STANDBY_PROMOTING; then
    echo "$(date): Master is down according to arbiter. Promoting standby..." >> $LOG_FILE
    promote_standby 

elif ! check_master && ! check_master_via_arbiter && $CHECK_STANDBY_PROMOTING; then
    echo "$(date): Master is down according to arbiter." >> $LOG_FILE

elif check_arbiter && check_master; then
    echo "$(date): Arbiter and master are both available." >> $LOG_FILE

elif ! check_arbiter && check_master; then
    echo "$(date): Arbiter is unavailable." >> $LOG_FILE

elif ! check_arbiter && ! check_master; then
    echo "$(date): Arbiter and master are both unavailable." >> $LOG_FILE

elif ! check_master && check_arbiter && check_master_via_arbiter; then
    echo "$(date): Master is available." >> $LOG_FILE
fi
