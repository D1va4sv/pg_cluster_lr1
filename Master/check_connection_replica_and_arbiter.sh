#!/bin/bash

# Параметры подключения к арбитру
ARBITER_HOST="192.168.111.144"
ARBITER_PORT="5433"

# Параметры подключения к реплике
REPLICA_HOST="192.168.111.143"
REPLICA_PORT="5432"

# Лог файл
LOG_FILE="/var/log/postgresql/master.log"

# Функция проверки доступности арбитра
check_arbiter() {
    nc -z "$ARBITER_HOST" "$ARBITER_PORT"
    return $?
}

# Функция проверки доступности реплики
check_replica() {
    pg_isready -h "$REPLICA_HOST" -p "$REPLICA_PORT"
    return $?
}

# Функция записи в лог
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Основная функция
main() {
    log_message "Starting master availability check..."

    if check_arbiter && check_replica; then
        log_message "Arbiter and replica are both available. Master is healthy."
    elif ! check_arbiter && ! check_replica; then
        log_message "Arbiter and replica are both unavailable. Shutting down master..."
        # Команда для выключения мастера
        systemctl stop postgresql
    elif ! check_arbiter; then
        log_message "Arbiter is unavailable. Master is still running."
    elif ! check_replica; then
        log_message "Replica is unavailable. Master is still running."
    fi
}

# Вызов основной функции
main
