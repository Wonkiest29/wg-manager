#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Файлы для загрузки
WG_MANAGER_SH="https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager.sh"
WG_MANAGER_PY="https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager.py"
WG_MANAGER="https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main/wg-manager"
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
    
    echo -e "Загрузка файлов..."
    
    # Проверяем наличие wget или curl
    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -q -O"
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -s -o"
    else
        echo -e "${RED}Не найдено инструментов для скачивания (wget или curl)!${NC}"
        echo -e "${YELLOW}Пытаюсь установить wget...${NC}"
        apt-get update && apt-get install -y wget || {
            echo -e "${RED}Не удалось установить wget. Проверьте соединение и права доступа.${NC}"
            rm -rf "$TMP_DIR"
            exit 1
        }
        DOWNLOAD_CMD="wget -q -O"
    fi
    
    # Скачиваем файлы напрямую
    $DOWNLOAD_CMD "$TMP_DIR/wg-manager.sh" "$WG_MANAGER_SH" || {
        echo -e "${RED}Не удалось скачать wg-manager.sh. Проверьте соединение и URL.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    $DOWNLOAD_CMD "$TMP_DIR/wg-manager.py" "$WG_MANAGER_PY" || {
        echo -e "${RED}Не удалось скачать wg-manager.py. Проверьте соединение и URL.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }

    $DOWNLOAD_CMD "$TMP_DIR/wg-manager" "$WG_MANAGER" || {
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
    
    # Копируем файлы из временной директории
    if [ -d "$TMP_DIR" ]; then
        if [ -f "$TMP_DIR/wg-manager.py" ]; then
            cp "$TMP_DIR/wg-manager.py" "$INSTALL_DIR/"
            echo -e "${GREEN}✓${NC} Установлен скрипт wg-manager.py"
        else
            echo -e "${RED}✗${NC} Файл wg-manager.py не найден!"
            exit 1
        fi
        
        if [ -f "$TMP_DIR/wg-manager.sh" ]; then
            cp "$TMP_DIR/wg-manager.sh" "$INSTALL_DIR/"
            echo -e "${GREEN}✓${NC} Установлен скрипт wg-manager.sh"
        fi
        
        if [ -f "$TMP_DIR/wg-manager" ]; then
            cp "$TMP_DIR/wg-manager" "$INSTALL_DIR/"
            echo -e "${GREEN}✓${NC} Установлен скрипт wg-manager"
        fi
    else
        echo -e "${RED}Ошибка: Временная директория не найдена${NC}"
        exit 1
    fi
    
    # Делаем скрипты исполняемыми
    chmod +x "$INSTALL_DIR/wg-manager.py"
    chmod +x "$INSTALL_DIR/wg-manager.sh"
    if [ -f "$INSTALL_DIR/wg-manager" ]; then
        chmod +x "$INSTALL_DIR/wg-manager"
    fi
    
    # Создаем символическую ссылку
    if [ -f "$INSTALL_DIR/wg-manager" ]; then
        ln -sf "$INSTALL_DIR/wg-manager" "$BIN_LINK"
    else
        ln -sf "$INSTALL_DIR/wg-manager.sh" "$BIN_LINK"
    fi
    
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
    
    # Проверяем наличие wget или curl
    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -q -O"
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -s -o"
    else
        echo -e "${RED}Не найдено инструментов для скачивания (wget или curl)!${NC}"
        echo -e "${YELLOW}Пытаюсь установить wget...${NC}"
        apt-get update && apt-get install -y wget || {
            echo -e "${RED}Не удалось установить wget. Проверьте соединение и права доступа.${NC}"
            rm -rf "$TMP_DIR"
            exit 1
        }
        DOWNLOAD_CMD="wget -q -O"
    fi
    
    # Скачиваем файлы напрямую
    echo -e "Скачивание последних версий файлов..."
    $DOWNLOAD_CMD "$TMP_DIR/wg-manager.sh" "$WG_MANAGER_SH" && \
    $DOWNLOAD_CMD "$TMP_DIR/wg-manager.py" "$WG_MANAGER_PY" && \
    $DOWNLOAD_CMD "$TMP_DIR/wg-manager" "$WG_MANAGER" || {
        echo -e "${RED}Ошибка при скачивании файлов. Проверьте соединение.${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    }
    
    # Проверяем, что скачанные файлы существуют
    if [ -f "$TMP_DIR/wg-manager.py" ] && [ -f "$TMP_DIR/wg-manager.sh" ]; then
        # Копируем новые версии файлов
        cp "$TMP_DIR/wg-manager.py" "$INSTALL_DIR/"
        cp "$TMP_DIR/wg-manager.sh" "$INSTALL_DIR/"
        cp "$TMP_DIR/wg-manager" "$INSTALL_DIR/"
        
        # Делаем скрипты исполняемыми
        chmod +x "$INSTALL_DIR/wg-manager.sh"
        chmod +x "$INSTALL_DIR/wg-manager.py"
        chmod +x "$INSTALL_DIR/wg-manager"
        
        echo -e "${GREEN}WireGuard Manager успешно обновлен.${NC}"
    else
        echo -e "${RED}Файлы не найдены после скачивания!${NC}"
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

    # Простой способ получения ввода с ограничением времени
    echo -e "Введите номер (1-4, 0) и нажмите Enter: "
    option=""
    read -r option

    # Простая обработка ввода без цикла
    case $option in
        1)
            echo -e "${GREEN}Запуск установки...${NC}"
            check_dependencies && download_wg_manager && install_wg_manager
            read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
            show_main_menu
            ;;
        2)
            echo -e "${BLUE}Запуск обновления...${NC}"
            update_wg_manager
            read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
            show_main_menu
            ;;
        3)
            echo -e "${RED}Запуск удаления...${NC}"
            uninstall_wg_manager
            read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
            show_main_menu
            ;;
        4)
            show_info
            read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
            show_main_menu
            ;;
        0|q|exit)
            echo -e "${GREEN}Выход из программы.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Некорректный выбор.${NC}"
            echo -e "Нажмите любую клавишу, чтобы вернуться в меню или Ctrl+C для выхода."
            read -n 1 -s
            show_main_menu
            ;;
    esac
}

# Запуск с обработкой ошибок
main() {
    # Перехват сигнала прерывания (Ctrl+C)
    trap 'echo -e "\n${RED}Прервано пользователем.${NC}"; exit 1' INT
    
    # Проверка прав
    check_root
    
    # Запуск меню
    show_main_menu
}

# Запуск главной функции с блокировкой повторного запуска
if [ -f "/tmp/wg_manager_installer.lock" ]; then
    pid=$(cat "/tmp/wg_manager_installer.lock")
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${RED}Установщик WireGuard Manager уже запущен (PID: $pid).${NC}"
        echo -e "Если это ошибка, удалите файл блокировки: ${BOLD}sudo rm /tmp/wg_manager_installer.lock${NC}"
        exit 1
    fi
fi

# Создание файла блокировки
echo $$ > "/tmp/wg_manager_installer.lock"

# Очистка при выходе
trap 'rm -f /tmp/wg_manager_installer.lock' EXIT

# Запуск
main
