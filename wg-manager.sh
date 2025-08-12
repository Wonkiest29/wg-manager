#!/bin/bash

# Находим реальный путь к скрипту независимо от того, откуда он вызван
SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" &> /dev/null && pwd )"

# Проверяем существование скрипта
if [ ! -f "$SCRIPT_DIR/wg-manager.py" ]; then
    # Если скрипт не найден в директории ссылки, пробуем поискать в директории исходного скрипта
    ORIGINAL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if [ -f "$ORIGINAL_DIR/wg-manager.py" ]; then
        SCRIPT_DIR="$ORIGINAL_DIR"
    else
        echo "Ошибка: не удалось найти скрипт wg-manager.py"
        echo "Текущая директория: $(pwd)"
        echo "Директория скрипта: $SCRIPT_DIR"
        echo "Исходная директория: $ORIGINAL_DIR"
        exit 1
    fi
fi

# Запускаем Python-скрипт с полным путем
python3 "$SCRIPT_DIR/wg-manager.py" "$@"
