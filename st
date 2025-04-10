#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода справки
show_help() {
    echo -e "${YELLOW}Использование:${NC}"
    echo "  st [команда] [параметры]"
    echo ""
    echo -e "${YELLOW}Команды:${NC}"
    echo "  deploy    - Развертывание стека"
    echo "  update    - Обновление сервиса"
    echo "  help      - Показать эту справку"
    echo ""
    echo -e "${YELLOW}Параметры для deploy:${NC}"
    echo "  -f, --file     - Путь к docker-compose файлу"
    echo "  -s, --stack    - Имя стека"
    echo ""
    echo -e "${YELLOW}Параметры для update:${NC}"
    echo "  -s, --stack    - Имя стека"
    echo "  -n, --service  - Имя сервиса"
}

# Проверка наличия команды
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Обработка команд
case "$1" in
    deploy)
        shift
        FILE=""
        STACK=""
        
        # Парсинг параметров
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -f|--file)
                    FILE="$2"
                    shift 2
                    ;;
                -s|--stack)
                    STACK="$2"
                    shift 2
                    ;;
                *)
                    echo -e "${RED}Неизвестный параметр: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done

        # Проверка обязательных параметров
        if [ -z "$FILE" ] || [ -z "$STACK" ]; then
            echo -e "${RED}Ошибка: Не указаны обязательные параметры${NC}"
            show_help
            exit 1
        fi

        # Выполнение развертывания
        echo -e "${GREEN}Развертывание стека $STACK...${NC}"
        ./deploy-stack.sh -f "$FILE" -s "$STACK"
        ;;
    
    update)
        shift
        STACK=""
        SERVICE=""
        
        # Парсинг параметров
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -s|--stack)
                    STACK="$2"
                    shift 2
                    ;;
                -n|--service)
                    SERVICE="$2"
                    shift 2
                    ;;
                *)
                    echo -e "${RED}Неизвестный параметр: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done

        # Проверка обязательных параметров
        if [ -z "$STACK" ] || [ -z "$SERVICE" ]; then
            echo -e "${RED}Ошибка: Не указаны обязательные параметры${NC}"
            show_help
            exit 1
        fi

        # Выполнение обновления
        echo -e "${GREEN}Обновление сервиса $SERVICE в стеке $STACK...${NC}"
        ./restart-service.sh -s "$STACK" -n "$SERVICE"
        ;;
    
    help)
        show_help
        ;;
    
    *)
        echo -e "${RED}Неизвестная команда: $1${NC}"
        show_help
        exit 1
        ;;
esac 