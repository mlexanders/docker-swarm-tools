#!/bin/bash
source "$(dirname "$0")/docker-utils.sh"

# Значения по умолчанию
STACK_NAME="stack"
COMPOSE_FILE="docker-compose.yml"

# Обработка аргументов командной строки
while getopts "f:s:" opt; do
    case $opt in
        f) COMPOSE_FILE="$OPTARG";;
        s) STACK_NAME="$OPTARG";;
        \?) error "Использование: $0 [-f compose-file] [-s stack-name]";;
    esac
done

# Проверка наличия необходимых файлов
if [ ! -f ".env" ]; then
    error "Файл .env не найден"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    error "Файл $COMPOSE_FILE не найден"
fi


export $(grep -v '^#' .env | xargs)


# Проверка подключения к Docker Swarm
if ! docker node ls &> /dev/null; then
    log "Docker Swarm не инициализирован. Инициализация..."
    run_command "docker swarm init" "Инициализация Docker Swarm"
fi


# Проверка существования стека
if docker stack ls | grep -q "$STACK_NAME"; then
    log "Стек $STACK_NAME уже существует. Обновление..."
    run_command "docker stack rm $STACK_NAME" "Удаление существующего стека"
    sleep 5
fi

# Развертывание стека
log "Развертывание стека..."
run_command "docker stack deploy --with-registry-auth --compose-file $COMPOSE_FILE $STACK_NAME -d" "Развертывание стека"

# Проверка статуса развертывания
log "Проверка статуса развертывания..."
sleep 5
run_command "docker stack services $STACK_NAME" "Проверка статуса сервисов"

# Проверяем статус всех сервисов
services=$(docker stack services "$STACK_NAME" | tail -n +2 | awk '{print $2}')
for service in $services; do
    check_service_status "$STACK_NAME" "$service"
done

log "Развертывание завершено"