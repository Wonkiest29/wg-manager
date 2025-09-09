#!/bin/bash

# WireGuard Manager Installer Script
# Поддерживает установку, обновление и удаление WireGuard Manager

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Константы
WG_MANAGER_DIR="/opt/wg-manager"
WG_MANAGER_BIN="/usr/local/bin/wg-manager"
GITHUB_BASE_URL="https://raw.githubusercontent.com/Wonkiest29/wg-privatenet/refs/heads/main"

# URL файлов
FILES=(
    "wg-manager.sh"
    "wg-manager.py"
    "wg-manager"
)

# Функция для вывода цветного текста
print_color() {
    printf "${1}${2}${NC}\n"
}

# Проверка, запущен ли скрипт через pipe
is_piped() {
    [[ ! -t 0 ]]
}

# Проверка root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "Ошибка: Этот скрипт должен запускаться с правами root"
        print_color $YELLOW "Используйте: sudo $0"
        exit 1
    fi
}

# Определение пакетного менеджера
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Установка зависимостей
install_dependencies() {
    print_color $BLUE "Проверка и установка зависимостей..."
    
    local pkg_manager=$(detect_package_manager)
    local missing_deps=()
    
    # Проверяем необходимые зависимости
    local deps=("git" "python3" "wireguard")
    
    # Добавляем wget или curl
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        deps+=("wget")
    fi
    
    for dep in "${deps[@]}"; do
        case $dep in
            "wireguard")
                if ! command -v wg >/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
                ;;
            *)
                if ! command -v "$dep" >/dev/null 2>&1; then
                    missing_deps+=("$dep")
                fi
                ;;
        esac
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        print_color $GREEN "Все зависимости уже установлены"
        return
    fi
    
    print_color $YELLOW "Отсутствующие зависимости: ${missing_deps[*]}"
    
    case $pkg_manager in
        "apt")
            apt update
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "wireguard")
                        apt install -y wireguard wireguard-tools
                        ;;
                    *)
                        apt install -y "$dep"
                        ;;
                esac
            done
            ;;
        "yum"|"dnf")
            local cmd=$pkg_manager
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "wireguard")
                        $cmd install -y wireguard-tools
                        ;;
                    *)
                        $cmd install -y "$dep"
                        ;;
                esac
            done
            ;;
        "pacman")
            pacman -Sy
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "wireguard")
                        pacman -S --noconfirm wireguard-tools
                        ;;
                    *)
                        pacman -S --noconfirm "$dep"
                        ;;
                esac
            done
            ;;
        "zypper")
            for dep in "${missing_deps[@]}"; do
                case $dep in
                    "wireguard")
                        zypper install -y wireguard-tools
                        ;;
                    *)
                        zypper install -y "$dep"
                        ;;
                esac
            done
            ;;
        *)
            print_color $RED "Неподдерживаемый пакетный менеджер. Установите зависимости вручную:"
            print_color $YELLOW "git, python3, wireguard-tools, wget (или curl)"
            exit 1
            ;;
    esac
    
    print_color $GREEN "Зависимости установлены успешно"
}

# Скачивание файла
download_file() {
    local filename="$1"
    local url="${GITHUB_BASE_URL}/${filename}"
    local output_path="${WG_MANAGER_DIR}/${filename}"
    
    print_color $BLUE "Скачивание ${filename}..."
    
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$output_path" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$output_path" "$url" --progress-bar
    else
        print_color $RED "Ошибка: не найден wget или curl"
        exit 1
    fi
    
    if [[ ! -f "$output_path" ]]; then
        print_color $RED "Ошибка: не удалось скачать $filename"
        exit 1
    fi
}

# Функция для получения пользовательского ввода
get_user_input() {
    local prompt="$1"
    local response
    echo -n "$prompt"
    read -r response
    echo "$response"
}

# Установка WireGuard Manager
install_wg_manager() {
    check_root
    print_color $GREEN "Начинаем установку WireGuard Manager..."
    
    # Установка зависимостей
    install_dependencies
    
    # Создание директории
    print_color $BLUE "Создание директории $WG_MANAGER_DIR..."
    mkdir -p "$WG_MANAGER_DIR"
    
    # Скачивание файлов
    for file in "${FILES[@]}"; do
        download_file "$file"
    done
    
    # Установка прав доступа
    print_color $BLUE "Установка прав доступа..."
    chmod +x "${WG_MANAGER_DIR}/wg-manager.sh"
    chmod +x "${WG_MANAGER_DIR}/wg-manager.py"
    chmod +x "${WG_MANAGER_DIR}/wg-manager"
    
    # Создание символьной ссылки
    print_color $BLUE "Создание символьной ссылки..."
    ln -sf "${WG_MANAGER_DIR}/wg-manager" "$WG_MANAGER_BIN"
    
    # Запрос интерфейса и подсети
    local wg_interface
    local wg_subnet
    wg_interface=$(get_user_input "Введите имя интерфейса WireGuard (например, wg0): ")
    if [[ -z "$wg_interface" ]]; then
        wg_interface="wg0"
    fi
    wg_subnet=$(get_user_input "Введите подсеть для клиентов (например, 10.8.0.): ")
    if [[ -z "$wg_subnet" ]]; then
        wg_subnet="10.8.0."
    fi

    # Создание settings.toml
    cat > "${WG_MANAGER_DIR}/settings.toml" <<EOF
CONF = "/etc/wireguard/${wg_interface}.conf"
SUBNET = "${wg_subnet}"
KEYS_DIR = "./keys"
ENDPOINT = "92.113.151.201:51820"
EOF
    
    print_color $GREEN "WireGuard Manager успешно установлен!"
    print_color $YELLOW "Для использования введите: wg-manager"
}

# Обновление WireGuard Manager
update_wg_manager() {
    check_root
    
    if [[ ! -d "$WG_MANAGER_DIR" ]]; then
        print_color $RED "Ошибка: WireGuard Manager не установлен"
        print_color $YELLOW "Используйте опцию установки"
        exit 1
    fi
    
    print_color $GREEN "Обновление WireGuard Manager..."
    
    # Создание резервной копии
    print_color $BLUE "Создание резервной копии..."
    local backup_dir="${WG_MANAGER_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    cp -r "$WG_MANAGER_DIR" "$backup_dir"
    
    # Скачивание новых версий
    for file in "${FILES[@]}"; do
        download_file "$file"
    done
    
    # Установка прав доступа
    chmod +x "${WG_MANAGER_DIR}/wg-manager.sh"
    chmod +x "${WG_MANAGER_DIR}/wg-manager.py"
    chmod +x "${WG_MANAGER_DIR}/wg-manager"
    
    # Обновление символьной ссылки
    ln -sf "${WG_MANAGER_DIR}/wg-manager" "$WG_MANAGER_BIN"
    
    print_color $GREEN "WireGuard Manager успешно обновлен!"
    print_color $BLUE "Резервная копия сохранена в: $backup_dir"
}

# Удаление WireGuard Manager
remove_wg_manager() {
    check_root
    
    if [[ ! -d "$WG_MANAGER_DIR" ]] && [[ ! -L "$WG_MANAGER_BIN" ]]; then
        print_color $YELLOW "WireGuard Manager не найден"
        exit 0
    fi
    
    print_color $YELLOW "Удаление WireGuard Manager..."
    
    # Удаление символьной ссылки
    if [[ -L "$WG_MANAGER_BIN" ]]; then
        print_color $BLUE "Удаление символьной ссылки..."
        rm -f "$WG_MANAGER_BIN"
    fi
    
    # Запрос подтверждения для удаления всей директории
    if [[ -d "$WG_MANAGER_DIR" ]]; then
        print_color $RED "ВНИМАНИЕ: Это удалит ВСЕ конфигурации и ключи WireGuard!"
        print_color $YELLOW "Директория: $WG_MANAGER_DIR"
        
        local response=$(get_user_input "Вы уверены, что хотите продолжить? [y/N]: ")
        
        case $response in
            [yY]|[yY][eE][sS])
                print_color $BLUE "Удаление директории $WG_MANAGER_DIR..."
                rm -rf "$WG_MANAGER_DIR"
                print_color $GREEN "WireGuard Manager полностью удален"
                ;;
            *)
                print_color $YELLOW "Удаление отменено. Директория $WG_MANAGER_DIR сохранена"
                ;;
        esac
    fi
    
    print_color $GREEN "Бинарный файл WireGuard Manager удален"
}

# Показать информацию об установке
show_info() {
    print_color $BLUE "=== Информация о WireGuard Manager ==="
    
    # Статус установки
    if [[ -d "$WG_MANAGER_DIR" ]] && [[ -L "$WG_MANAGER_BIN" ]]; then
        print_color $GREEN "Статус: Установлен"
        print_color $BLUE "Директория: $WG_MANAGER_DIR"
        print_color $BLUE "Исполняемый файл: $WG_MANAGER_BIN"
        
        # Проверка файлов
        echo -e "\nФайлы:"
        for file in "${FILES[@]}"; do
            if [[ -f "${WG_MANAGER_DIR}/${file}" ]]; then
                print_color $GREEN "  ✓ $file"
            else
                print_color $RED "  ✗ $file (отсутствует)"
            fi
        done
    else
        print_color $RED "Статус: Не установлен"
    fi
    
    echo -e "\nЗависимости:"
    local deps=("git" "python3" "wg" "wget" "curl")
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            local version=""
            case $dep in
                "python3") version=" ($(python3 --version 2>&1 | cut -d' ' -f2))" ;;
                "git") version=" ($(git --version 2>&1 | cut -d' ' -f3))" ;;
                "wg") version=" ($(wg --version 2>&1 | head -1))" ;;
            esac
            print_color $GREEN "  ✓ $dep$version"
        else
            print_color $RED "  ✗ $dep (не установлен)"
        fi
    done
    
    # Информация о системе
    echo -e "\nСистемная информация:"
    print_color $BLUE "  OS: $(uname -s)"
    print_color $BLUE "  Kernel: $(uname -r)"
    print_color $BLUE "  Архитектура: $(uname -m)"
    print_color $BLUE "  Пакетный менеджер: $(detect_package_manager)"
}

# Интерактивное меню выбора действия
show_menu() {
    clear
    print_color $BLUE "=================================="
    print_color $BLUE "   WireGuard Manager Installer"
    print_color $BLUE "=================================="
    echo ""
    
    # Проверка статуса установки
    if [[ -d "$WG_MANAGER_DIR" ]] && [[ -L "$WG_MANAGER_BIN" ]]; then
        print_color $GREEN "Статус: WireGuard Manager установлен"
    else
        print_color $YELLOW "Статус: WireGuard Manager не установлен"
    fi
    
    echo ""
    print_color $YELLOW "Выберите действие:"
    echo "1) Установить WireGuard Manager"
    echo "2) Обновить WireGuard Manager"
    echo "3) Удалить WireGuard Manager"
    echo "4) Показать информацию"
    echo "5) Выход"
    echo ""
}

# Интерактивный режим
interactive_mode() {
    local choice
    
    while true; do
        show_menu
        echo -n "Введите номер (1-5): "
        read -r choice
        
        case "$choice" in
            "1")
                echo ""
                install_wg_manager
                echo ""
                echo -n "Нажмите Enter для продолжения..."
                read -r
                ;;
            "2")
                echo ""
                update_wg_manager
                echo ""
                echo -n "Нажмите Enter для продолжения..."
                read -r
                ;;
            "3")
                echo ""
                remove_wg_manager
                echo ""
                echo -n "Нажмите Enter для продолжения..."
                read -r
                ;;
            "4")
                echo ""
                show_info
                echo ""
                echo -n "Нажмите Enter для продолжения..."
                read -r
                ;;
            "5")
                print_color $GREEN "До свидания!"
                exit 0
                ;;
            *)
                print_color $RED "Неверный выбор. Пожалуйста, введите число от 1 до 5."
                sleep 2
                ;;
        esac
    done
}

# Показать справку
show_help() {
    echo "WireGuard Manager Installer"
    echo "Использование: $0 [ДЕЙСТВИЕ]"
    echo ""
    echo "Действия:"
    echo "  install       Установить WireGuard Manager"
    echo "  update        Обновить WireGuard Manager"
    echo "  remove        Удалить WireGuard Manager"
    echo "  info          Показать информацию об установке"
    echo "  menu          Запустить интерактивное меню"
    echo "  help          Показать эту справку"
    echo ""
    echo "Если запустить без параметров, откроется интерактивное меню."
    echo ""
    echo "Примеры:"
    echo "  $0                    # Интерактивное меню"
    echo "  $0 install            # Прямая установка"
    echo "  $0 update             # Прямое обновление"
    echo "  $0 remove             # Прямое удаление"
    echo "  $0 info               # Показать информацию"
    echo ""
    echo "Запуск через curl:"
    echo "  curl -s URL | bash                    # Интерактивное меню"
    echo "  curl -s URL | bash -s install         # Прямая установка"
    echo "  curl -s URL | bash -s info            # Показать информацию"
}

# Основная логика
main() {
    # Если скрипт запущен без параметров, запускаем интерактивное меню
    if [[ $# -eq 0 ]]; then
        interactive_mode
        return
    fi
    
    case "${1:-}" in
        "install")
            install_wg_manager
            ;;
        "update")
            update_wg_manager
            ;;
        "remove"|"uninstall")
            remove_wg_manager
            ;;
        "info"|"status")
            show_info
            ;;
        "menu"|"interactive")
            interactive_mode
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_color $RED "Неизвестное действие: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск скрипта
main "$@"
