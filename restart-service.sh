#!/bin/bash
source "$(dirname "$0")/docker-utils.sh"

# Значения по умолчанию
STACK_NAME="stack"
SERVICE_NAME=""

# Обработка аргументов командной строки
while getopts "s:n:" opt; do
    case $opt in
        s) STACK_NAME="$OPTARG";;
        n) SERVICE_NAME="$OPTARG";;
        \?) error "Использование: $0 [-s stack-name] -n service-name";;
    esac
done

# Проверка обязательных параметров
if [ -z "$SERVICE_NAME" ]; then
    error "Не указано имя сервиса. Использование: $0 [-s stack-name] -n service-name"
fi

# Проверка существования стека и сервиса
check_stack_exists "$STACK_NAME"
check_service_exists "$STACK_NAME" "$SERVICE_NAME"

# Получаем список контейнеров сервиса
log "Поиск контейнеров сервиса $SERVICE_NAME..."
containers=$(docker stack ps "$STACK_NAME" --filter "name=${STACK_NAME}_${SERVICE_NAME}" --format "{{.ID}}")

if [ -z "$containers" ]; then
    error "Не найдены контейнеры сервиса $SERVICE_NAME"
fi

# Получаем образ сервиса
log "Получение образа сервиса $SERVICE_NAME..."
image=$(docker service inspect "${STACK_NAME}_${SERVICE_NAME}" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')
run_command "docker pull $image" "Обновление образа"

# Перезапуск сервиса
log "Перезапуск сервиса $SERVICE_NAME..."
run_command "docker service update --force ${STACK_NAME}_${SERVICE_NAME}" "Перезапуск сервиса"

# Проверка статуса после перезапуска
log "Проверка статуса сервиса..."
sleep 5
run_command "docker stack services $STACK_NAME" "Проверка статуса сервисов"
check_service_status "$STACK_NAME" "$SERVICE_NAME"

log "Перезапуск завершен" 