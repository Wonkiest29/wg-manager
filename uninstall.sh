#!/bin/bash
#
# Удаление WireGuard Manager из системы
#

# Проверяем, запущен ли скрипт с правами root
if [ "$EUID" -ne 0 ]; then
  echo "Для удаления требуются права администратора."
  echo "Запустите скрипт командой: sudo bash uninstall.sh"
  exit 1
fi

# Удаляем символическую ссылку из /usr/local/bin
if [ -L "/usr/local/bin/wg-manager" ]; then
  rm /usr/local/bin/wg-manager
  echo "Ссылка на WireGuard Manager удалена из /usr/local/bin"
else
  echo "Ссылка на WireGuard Manager не найдена в /usr/local/bin"
fi

# Удаляем установочную директорию
if [ -d "/opt/wg-manager" ]; then
  rm -rf "/opt/wg-manager"
  echo "Директория WireGuard Manager удалена из /opt/wg-manager"
fi

echo "WireGuard Manager успешно удален из системы"
