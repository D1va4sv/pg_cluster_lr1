#!/bin/bash

# Параметры подключения к базе данных

# Время ожидания ответа в секундах
TIMEOUT=3

# Переменные для подсчета успешных и ошибочных запросов
echo 0 > suc
echo 0 > err

# Функция для выполнения запроса и проверки времени выполнения
execute_query() {
    # Выполнение запроса и измерение времени выполнения
    START_TIME=$(date +%s)
    psql -d test1 -c "insert into test(date) values (now());" &>/dev/null
    END_TIME=$(date +%s)
    ELAPSED_TIME=$((END_TIME - START_TIME))

    # Проверка времени выполнения запроса
    if [ $ELAPSED_TIME -le $TIMEOUT ]; then
        echo "$(date): Query succeeded" >> stats.log
        echo $(($(cat suc) + 1)) > suc
    else
        echo "$(date): Query timed out" >> stats.log
        echo $(($(cat err) + 1)) > err
        echo 2
    fi
}

# Цикл для выполнения 1000000000 запросов с различными настройками synchronous_commit
for synchronous_commit_setting in "off" "local" "remote_write" "on" "remote_apply"; do
    echo "Testing synchronous_commit = $synchronous_commit_setting"
    
    # Установка synchronous_commit
    ssh -t -l root 192.168.111.143 sudo -u postgres psql -d test1 -c "SET synchronous_commit TO $synchronous_commit_setting;"
    psql -d test1 -c "SET synchronous_commit TO $synchronous_commit_setting;"

    # Выполнение 1000000000 запросов
    for ((i=1; i<=1000000000; i++)); do
        execute_query &
        sleep $((RANDOM % 1000))e-3
    done

    # Ожидание завершения всех фоновых процессов
    wait

    # Подсчет фактически вставленных строк
    echo "Actual rows inserted (synchronous_commit = $synchronous_commit_setting):"
    psql -d test1 -c "select count(*) from test;"
    ssh -t -l root 192.168.111.143 sudo -u postgres psql -d test1 -c "select count(*) from test;"

    # Вывод итоговой статистики успшных и неуспешный вставок.
    echo "Total successful queries: $(cat suc)"
    echo "Total error queries: $(cat err)"
done