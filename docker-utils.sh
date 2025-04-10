#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

debug() {
    echo -e "${YELLOW}[DEBUG] $1${NC}"
}

# Функция для выполнения команд с выводом
run_command() {
    local cmd="$1"
    local description="$2"
    log "Выполнение: $description"
    debug "Команда: $cmd"
    output=$($cmd 2>&1)
    local status=$?
    if [ $status -ne 0 ]; then
        error "Ошибка выполнения команды: $output"
    else
        debug "Результат: $output"
    fi
    return $status
}


# Функция проверки существования стека
check_stack_exists() {
    local stack_name="$1"
    if ! docker stack ls | grep -q "$stack_name"; then
        error "Стек $stack_name не найден"
    fi
}

# Функция проверки существования сервиса
check_service_exists() {
    local stack_name="$1"
    local service_name="$2"
    if ! docker stack services "$stack_name" | grep -q "$service_name"; then
        error "Сервис $service_name не найден в стеке $stack_name"
    fi
}

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