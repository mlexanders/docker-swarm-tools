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

# Функция проверки Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен"
    fi
    run_command "docker info" "Проверка подключения к Docker"
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

# Функция проверки статуса сервиса
check_service_status() {
    local stack_name="$1"
    local service_name="$2"
    local service_status=$(docker stack services "$stack_name" | grep "$service_name")
    local replicas=$(echo "$service_status" | awk '{print $4}')
    local current=$(echo "$replicas" | cut -d'/' -f1)
    local desired=$(echo "$replicas" | cut -d'/' -f2)
    
    if [ "$current" -eq "$desired" ]; then
        log "Сервис $service_name успешно запущен"
        log "Текущий статус: $replicas реплик"
        return 0
    else
        error "Сервис $service_name не запущен успешно. Текущий статус: $replicas реплик"
    fi
} 