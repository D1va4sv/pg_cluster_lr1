#!/bin/bash

# Параметры подключения к мастеру
MASTER_HOST="192.168.111.139"
MASTER_PORT="5432"

# Параметры подключения к реплике
REPLICA_HOST="192.168.111.143"
REPLICA_PORT="5432"

# Лог файл
LOG_FILE="/var/log/postgresql/arbiter.log"

# Функция проверки доступности мастера
check_master() {
    pg_isready -h "$MASTER_HOST" -p "$MASTER_PORT"
    return $?
}

# Функция проверки доступности реплики
check_replica() {
    pg_isready -h "$REPLICA_HOST" -p "$REPLICA_PORT"
    return $?
}

# Основной блок
while true; do
    echo "$(date): Listening for status requests on port 5433..." >> "$LOG_FILE"
    {
        if check_master && check_replica; then
            echo "$(date): Master and replica are both available." >> "$LOG_FILE"
            echo -e "HTTP/1.1 200 OK\r\nContent-Length: 14\r\n\r\nOK"
        elif ! check_master && ! check_replica; then
            echo "$(date): Master and replica are both unavailable." >> "$LOG_FILE"
            echo -e "HTTP/1.1 200 OK\r\nContent-Length: 26\r\n\r\nMaster and replica down"
        elif ! check_master; then
            echo "$(date): Master is unavailable." >> "$LOG_FILE"
            echo -e "HTTP/1.1 200 OK\r\nContent-Length: 16\r\n\r\nMaster down"
        elif ! check_replica; then
            echo "$(date): Replica is unavailable." >> "$LOG_FILE"
            echo -e "HTTP/1.1 200 OK\r\nContent-Length: 17\r\n\r\nReplica down"
        fi
    } | nc -l -p 5433 -q 1
done
