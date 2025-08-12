#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Репозиторий GitHub (замените на свой репозиторий)
REPO_URL="https://github.com/username/wg-manager.git"
INSTALL_DIR="/opt/wg-manager"
BIN_LINK="/usr/local/bin/wg-manager"

# Проверка на root права
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Этот скрипт должен быть запущен с правами суперпользователя (root).${NC}"
        echo -e "Выполните: ${BOLD}sudo bash $0${NC}"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    echo -e "${BLUE}Проверка зависимостей...${NC}"
    
    # Проверка наличия git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}Git не найден. Устанавливаем...${NC}"
        apt-get update && apt-get install -y git || {
            echo -e "${RED}Не удалось установить git. Проверьте соединение и права доступа.${NC}"
            exit 1
        }
    fi
    
    # Проверка наличия python3
    if ! command -v python3 &> /dev/null; then
        echo -e "${YELLOW}Python3 не найден. Устанавливаем...${NC}"
        apt-get update && apt-get install -y python3 || {
            echo -e "${RED}Не удалось установить Python3. Проверьте соединение и права доступа.${NC}"
            exit 1
        }
    fi
    
    # Проверка наличия wireguard
    if ! command -v wg &> /dev/null; then
        echo -e "${YELLOW}WireGuard не найден. Устанавливаем...${NC}"
        apt-get update && apt-get install -y wireguard || {
            echo -e "${RED}Не удалось установить WireGuard. Проверьте соединение и права доступа.${NC}"
            exit 1
        }
    fi
    
    echo -e "${GREEN}Все зависимости установлены.${NC}"
}

# Скачивание WireGuard Manager
download_wg_manager() {
    echo -e "${BLUE}Скачивание WireGuard Manager...${NC}"
    
    # Создаем временную директорию
    TMP_DIR=$(mktemp -d)
    
    # Скачиваем файлы напрямую
    wget -q -O "$TMP_DIR/wg-manager.sh" "https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager.sh" || {
        echo -e "${RED}Не удалось скачать wg-manager.sh. Проверьте соединение и URL.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    wget -q -O "$TMP_DIR/wg-manager.py" "https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager.py" || {
        echo -e "${RED}Не удалось скачать wg-manager.py. Проверьте соединение и URL.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }

    wget -q -O "$TMP_DIR/wg-manager" "https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager" || {
        echo -e "${RED}Не удалось скачать wg-manager. Проверьте соединение и URL.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    echo -e "${GREEN}Файлы WireGuard Manager успешно скачаны.${NC}"
    return 0
}

# Установка WireGuard Manager
install_wg_manager() {
    echo -e "${BLUE}Установка WireGuard Manager...${NC}"
    
    # Создаем директорию для установки
    mkdir -p "$INSTALL_DIR"
    
    # Копируем файлы из временной директории или текущей директории
    if [ -d "$TMP_DIR" ] && [ -f "$TMP_DIR/wg-manager.py" ]; then
        cp "$TMP_DIR/wg-manager.py" "$INSTALL_DIR/"
    else
        cp "wg-manager.py" "$INSTALL_DIR/"
    fi
    
    # Создаем скрипт-обертку для запуска
    cat > "$INSTALL_DIR/wg-manager.sh" << 'EOF'
#!/bin/bash

# Находим путь к скрипту
SCRIPT_DIR="/opt/wg-manager"

# Проверка существования основного скрипта
if [ ! -f "$SCRIPT_DIR/wg-manager.py" ]; then
    echo "Ошибка: Файл wg-manager.py не найден в $SCRIPT_DIR"
    exit 1
fi

# Запуск скрипта с передачей всех аргументов
python3 "$SCRIPT_DIR/wg-manager.py" "$@"
EOF
    
    # Делаем скрипты исполняемыми
    chmod +x "$INSTALL_DIR/wg-manager.py"
    chmod +x "$INSTALL_DIR/wg-manager.sh"
    
    # Создаем символическую ссылку
    ln -sf "$INSTALL_DIR/wg-manager.sh" "$BIN_LINK"
    
    # Создаем директорию для ключей, если её нет
    mkdir -p "$INSTALL_DIR/keys"
    
    echo -e "${GREEN}WireGuard Manager успешно установлен.${NC}"
    echo -e "Запустите его командой: ${BOLD}wg-manager${NC}"
    
    # Удаляем временную директорию, если она существует
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

# Удаление WireGuard Manager
uninstall_wg_manager() {
    echo -e "${BLUE}Удаление WireGuard Manager...${NC}"
    
    # Удаляем символическую ссылку
    if [ -L "$BIN_LINK" ]; then
        rm "$BIN_LINK"
        echo -e "${GREEN}Символическая ссылка удалена.${NC}"
    else
        echo -e "${YELLOW}Символическая ссылка не найдена.${NC}"
    fi
    
    # Предлагаем сохранить конфигурационные файлы
    if [ -d "$INSTALL_DIR" ]; then
        read -p "Удалить все конфигурационные файлы и ключи? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}Директория установки и все файлы удалены.${NC}"
        else
            # Удаляем только программные файлы, оставляем конфиги и ключи
            rm -f "$INSTALL_DIR/wg-manager.py" "$INSTALL_DIR/wg-manager.sh"
            echo -e "${GREEN}Программные файлы удалены. Конфигурации и ключи сохранены в $INSTALL_DIR${NC}"
        fi
    else
        echo -e "${YELLOW}Директория установки не найдена.${NC}"
    fi
    
    echo -e "${GREEN}WireGuard Manager успешно удален из системы.${NC}"
}

# Обновление WireGuard Manager
update_wg_manager() {
    echo -e "${BLUE}Обновление WireGuard Manager...${NC}"
    
    # Создаем временную директорию
    TMP_DIR=$(mktemp -d)
    
    # Пытаемся клонировать репозиторий
    if git clone "$REPO_URL" "$TMP_DIR" &> /dev/null; then
        # Проверяем, что скачанный файл действительно существует
        if [ -f "$TMP_DIR/wg-manager.py" ]; then
            # Копируем новую версию скрипта
            cp "$TMP_DIR/wg-manager.py" "$INSTALL_DIR/"
            echo -e "${GREEN}WireGuard Manager успешно обновлен.${NC}"
        else
            echo -e "${RED}Файл wg-manager.py не найден в репозитории!${NC}"
            rm -rf "$TMP_DIR"
            exit 1
        fi
    else
        echo -e "${RED}Не удалось скачать обновление. Проверьте соединение или URL репозитория.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # Удаляем временную директорию
    rm -rf "$TMP_DIR"
}

# Показываем информацию о программе
show_info() {
    echo -e "${BOLD}${BLUE}WireGuard Manager${NC}"
    echo -e "Интерактивный менеджер для WireGuard VPN\n"
    
    # Проверяем наличие установленных файлов
    if [ -f "$INSTALL_DIR/wg-manager.py" ]; then
        echo -e "${GREEN}✓ WireGuard Manager установлен${NC}"
        echo -e "   Директория установки: ${BOLD}$INSTALL_DIR${NC}"
        echo -e "   Команда запуска: ${BOLD}wg-manager${NC}"
    else
        echo -e "${RED}✗ WireGuard Manager не установлен${NC}"
    fi
    
    # Проверяем зависимости
    echo -e "\nЗависимости:"
    if command -v python3 &> /dev/null; then
        python_version=$(python3 --version 2>&1)
        echo -e "${GREEN}✓ Python3 установлен ($python_version)${NC}"
    else
        echo -e "${RED}✗ Python3 не установлен${NC}"
    fi
    
    if command -v wg &> /dev/null; then
        wireguard_version=$(wg --version 2>&1 | head -n1)
        echo -e "${GREEN}✓ WireGuard установлен ($wireguard_version)${NC}"
    else
        echo -e "${RED}✗ WireGuard не установлен${NC}"
    fi
    
    echo -e "\n${YELLOW}Для управления WireGuard VPN выполните команду:${NC} ${BOLD}wg-manager${NC}"
}

# Главное меню
show_main_menu() {
    clear
    echo -e "${BOLD}${BLUE}===============================${NC}"
    echo -e "${BOLD}${BLUE}     WireGuard Manager Tool    ${NC}"
    echo -e "${BOLD}${BLUE}===============================${NC}\n"
    
    echo -e "${BOLD}Выберите действие:${NC}"
    echo -e "${GREEN}1.${NC} Установить WireGuard Manager"
    echo -e "${BLUE}2.${NC} Обновить WireGuard Manager"
    echo -e "${RED}3.${NC} Удалить WireGuard Manager"
    echo -e "${YELLOW}4.${NC} Информация"
    echo -e "${RED}0.${NC} Выход\n"

    local attempts=0
    local max_attempts=3

    while [ $attempts -lt $max_attempts ]; do
        read -p "Ваш выбор: " option
        case $option in
            1) check_dependencies && download_wg_manager && install_wg_manager; return ;;
            2) update_wg_manager; return ;;
            3) uninstall_wg_manager; return ;;
            4) show_info; return ;;
            0) echo -e "${GREEN}Выход из программы.${NC}"; exit 0 ;;
            *) echo -e "${RED}Некорректный выбор. Повторите попытку.${NC}"; attempts=$((attempts + 1)) ;;
        esac
    done

    echo -e "${RED}Превышено количество попыток. Завершение программы.${NC}"
    exit 1
}

# Главная функция
main() {
    check_root
    show_main_menu
}

# Запуск главной функции
main
