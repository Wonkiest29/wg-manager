#!/bin/bash
# WireGuard Manager Installer — переписанный с нуля

# ===== Цвета =====
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

# ===== Константы =====
INSTALL_DIR="/opt/wg-manager"
BIN_LINK="/usr/local/bin/wg-manager"
REPO_BASE="https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main"
FILES=("wg-manager.sh" "wg-manager.py" "wg-manager")
TMP_DIR=$(mktemp -d)

# ===== Проверка root =====
require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Скрипт нужно запускать с правами root.${NC}"
        echo -e "Используйте: ${BOLD}sudo bash $0${NC}"
        exit 1
    fi
}

# ===== Проверка и установка зависимости =====
require_dep() {
    local pkg="$1"
    if ! command -v "$pkg" &>/dev/null; then
        echo -e "${YELLOW}Не найдено: $pkg. Устанавливаю...${NC}"
        apt-get update && apt-get install -y "$pkg" || {
            echo -e "${RED}Не удалось установить $pkg.${NC}"; exit 1;
        }
    fi
}

check_dependencies() {
    echo -e "${BLUE}Проверка зависимостей...${NC}"
    require_dep git
    require_dep python3
    require_dep wg
    require_dep wget
    echo -e "${GREEN}Все зависимости установлены.${NC}"
}

# ===== Скачивание файлов =====
download_files() {
    echo -e "${BLUE}Скачивание файлов...${NC}"
    for file in "${FILES[@]}"; do
        wget -q -O "$TMP_DIR/$file" "$REPO_BASE/$file" || {
            echo -e "${RED}Ошибка скачивания: $file${NC}"; rm -rf "$TMP_DIR"; exit 1;
        }
    done
    echo -e "${GREEN}Скачивание завершено.${NC}"
}

# ===== Установка =====
install_manager() {
    mkdir -p "$INSTALL_DIR/keys"
    cp "$TMP_DIR"/* "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/*
    ln -sf "$INSTALL_DIR/wg-manager" "$BIN_LINK"
    echo -e "${GREEN}WireGuard Manager установлен.${NC}"
}

# ===== Обновление =====
update_manager() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}WireGuard Manager не установлен.${NC}"
        exit 1
    fi
    download_files
    cp "$TMP_DIR"/* "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/*
    echo -e "${GREEN}Обновление завершено.${NC}"
}

# ===== Удаление =====
uninstall_manager() {
    rm -f "$BIN_LINK"
    if [ -d "$INSTALL_DIR" ]; then
        read -p "Удалить все файлы, включая ключи? (y/n): " ans
        [[ "$ans" =~ ^[Yy]$ ]] && rm -rf "$INSTALL_DIR" || rm -f "$INSTALL_DIR"/wg-manager{,.sh,.py}
    fi
    echo -e "${GREEN}Удаление завершено.${NC}"
}

# ===== Информация =====
show_info() {
    echo -e "${BOLD}${BLUE}WireGuard Manager${NC}"
    if [ -f "$INSTALL_DIR/wg-manager.py" ]; then
        echo -e "${GREEN}✓ Установлен${NC} в ${BOLD}$INSTALL_DIR${NC}"
    else
        echo -e "${RED}✗ Не установлен${NC}"
    fi
    python3 --version &>/dev/null && echo -e "${GREEN}✓ Python3${NC}" || echo -e "${RED}✗ Python3${NC}"
    wg --version &>/dev/null && echo -e "${GREEN}✓ WireGuard${NC}" || echo -e "${RED}✗ WireGuard${NC}"
}

# ===== Меню =====
menu() {
    clear
    echo -e "${BOLD}${BLUE}WireGuard Manager Installer${NC}"
    echo -e "1) Установить\n2) Обновить\n3) Удалить\n4) Инфо\n0) Выход"
    read -p "Выбор: " opt
    case "$opt" in
        1) check_dependencies; download_files; install_manager ;;
        2) update_manager ;;
        3) uninstall_manager ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac
    read -n1 -s -r -p "Нажмите любую клавишу..."
    menu
}

# ===== Запуск =====
require_root
menu
