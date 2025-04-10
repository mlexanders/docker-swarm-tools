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

# Функция для загрузки и проверки образа
pull_and_wait_image() {
    local image_name=$1
    local max_attempts=30
    local attempt=1
    local sleep_time=10

    echo "[INFO] Загрузка образа $image_name..."
    run_command "docker pull $image_name" "Загрузка образа $image_name"
    
    while [ $attempt -le $max_attempts ]; do
        if docker image inspect "$image_name" &>/dev/null; then
            echo "[INFO] Образ $image_name успешно загружен"
            return 0
        fi
        
        echo "[INFO] Попытка $attempt из $max_attempts: ожидание загрузки образа $image_name..."
        sleep $sleep_time
        attempt=$((attempt + 1))
    done
    
    echo "[ERROR] Превышено время ожидания загрузки образа $image_name"
    return 1
}

# Функция для проверки статуса сервиса
check_service_status() {
    local stack_name=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    local sleep_time=10

    echo "[INFO] Проверка статуса сервиса $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        local status=$(docker service ls --filter "name=${stack_name}_${service_name}" --format "{{.Replicas}}")
        
        if [[ $status == *"1/1"* ]] || [[ $status == *"2/2"* ]]; then
            echo "[INFO] Сервис $service_name успешно запущен"
            return 0
        fi
        
        echo "[INFO] Попытка $attempt из $max_attempts: текущий статус - $status"
        sleep $sleep_time
        attempt=$((attempt + 1))
    done
    
    echo "[ERROR] Сервис $service_name не запущен успешно. Текущий статус: $status"
    return 1
}

# Функция для развертывания стека
deploy_stack() {
    local compose_file=$1
    local stack_name=$2
    
    echo "[INFO] Начало развертывания стека $stack_name..."
    
    # Получаем список образов из docker-compose файла
    local images=$(docker-compose -f "$compose_file" config | grep "image:" | awk '{print $2}')
    
    # Загружаем и проверяем каждый образ
    for image in $images; do
        pull_and_wait_image "$image" || return 1
    done
    
    # Развертываем стек
    run_command "docker stack deploy -c $compose_file $stack_name" "Развертывание стека $stack_name"
    
    # Проверяем статус каждого сервиса
    local services=$(docker stack services "$stack_name" --format "{{.Name}}" | sed "s/${stack_name}_//")
    for service in $services; do
        check_service_status "$stack_name" "$service" || return 1
    done
    
    echo "[INFO] Стек $stack_name успешно развернут"
    return 0
}

# Развертывание стека
log "Развертывание стека..."
deploy_stack "$COMPOSE_FILE" "$STACK_NAME"

log "Развертывание завершено"