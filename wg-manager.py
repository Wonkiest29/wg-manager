#!/usr/bin/env python3
import os
import re
import subprocess
import sys
import datetime
import time
import shutil

# Настройки
CONF = "./wg0.conf"
SUBNET = "10.8.0."
KEYS_DIR = "./keys"
ENDPOINT = "92.113.151.201:51820"  # Внешний эндпоинт сервера

# Цвета для терминала
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

# Создание директории для ключей, если её нет
def ensure_keys_dir():
    if not os.path.exists(KEYS_DIR):
        os.makedirs(KEYS_DIR)

# Очистка экрана
def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

# Декоратор для красивого вывода функций
def menu_decorator(func):
    def wrapper(*args, **kwargs):
        clear_screen()
        print_header()
        result = func(*args, **kwargs)
        return result
    return wrapper

# Красивый заголовок
def print_header():
    width = shutil.get_terminal_size().columns
    print(Colors.CYAN + "=" * width + Colors.ENDC)
    title = "WireGuard Manager"
    print(Colors.BOLD + Colors.GREEN + title.center(width) + Colors.ENDC)
    print(Colors.CYAN + "=" * width + Colors.ENDC)
    print()

# Проверка доступности команды wg
def check_wg_command():
    try:
        subprocess.run(["wg", "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"{Colors.FAIL}Ошибка: команда 'wg' не найдена. Установите WireGuard и добавьте wg в PATH.{Colors.ENDC}")
        input("\nНажмите Enter для выхода...")
        sys.exit(1)

# Выполнение команды и возврат результата
def run_command(command):
    result = subprocess.run(command, shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        print(f"{Colors.FAIL}Ошибка при выполнении команды: {command}{Colors.ENDC}")
        print(f"{Colors.FAIL}{result.stderr}{Colors.ENDC}")
        input("\nНажмите Enter для продолжения...")
        return None
    return result.stdout.strip()

# Поиск свободного IP
def find_free_ip():
    for i in range(2, 255):
        ip = f"{SUBNET}{i}"
        grep_cmd = f"grep -q \"AllowedIPs = {ip}/32\" {CONF}"
        result = os.system(grep_cmd)
        if result != 0:  # IP свободен
            return ip
    
    print(f"{Colors.FAIL}Свободных IP не найдено{Colors.ENDC}")
    return None

# Получение имени клиента из конфига по его IP
def get_client_name_by_ip(ip):
    with open(CONF, 'r') as f:
        content = f.readlines()
    
    for i, line in enumerate(content):
        if line.strip().startswith('# Client:'):
            name = line.strip().replace('# Client:', '').strip()
            for j in range(i+1, min(i+5, len(content))):
                if 'AllowedIPs' in content[j] and ip in content[j]:
                    return name
    return None

# Получение списка всех клиентов
def get_all_clients():
    clients = []
    if not os.path.exists(CONF):
        return clients
    
    with open(CONF, 'r') as f:
        content = f.readlines()
    
    i = 0
    while i < len(content):
        line = content[i].strip()
        if line.startswith('# Client:'):
            name = line.replace('# Client:', '').strip()
            ip = None
            for j in range(i+1, min(i+5, len(content))):
                if j < len(content) and 'AllowedIPs' in content[j]:
                    ip_match = re.search(r'AllowedIPs\s*=\s*([0-9.]+)/32', content[j])
                    if ip_match:
                        ip = ip_match.group(1)
                        break
            if ip:
                clients.append((name, ip))
        i += 1
    
    return clients

@menu_decorator
def add_client():
    print(f"{Colors.BOLD}Добавление нового клиента{Colors.ENDC}\n")
    
    client_name = input("Введите имя клиента (или нажмите Enter для автогенерации): ")
    if not client_name:
        timestamp = datetime.datetime.now().strftime("%s")
        client_name = f"client-{timestamp}"
    
    client_ip = find_free_ip()
    if not client_ip:
        return
    
    try:
        with open(CONF, 'r') as f:
            content = f.read()
        
        server_priv_match = re.search(r'PrivateKey\s*=\s*(\S+)', content)
        if not server_priv_match:
            print(f"{Colors.FAIL}Не удалось найти приватный ключ в {CONF}{Colors.ENDC}")
            input("\nНажмите Enter для возврата в меню...")
            return
        
        server_priv = server_priv_match.group(1)
        
        # Получение публичного ключа сервера
        proc = subprocess.run(["wg", "pubkey"], input=server_priv+"\n", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            print(f"{Colors.FAIL}Не удалось получить публичный ключ сервера: {proc.stderr}{Colors.ENDC}")
            input("\nНажмите Enter для возврата в меню...")
            return
        server_pub = proc.stdout.strip()
        
        # Генерация ключей клиента
        client_priv = run_command("wg genkey")
        if not client_priv:
            return
        client_pub = run_command(f"echo '{client_priv}' | wg pubkey")
        if not client_pub:
            return
        psk = run_command("wg genpsk")
        if not psk:
            return
        
        # Добавление клиента в серверный конфиг
        with open(CONF, 'a') as f:
            f.write(f"""
# Client: {client_name}
[Peer]
PublicKey = {client_pub}
PresharedKey = {psk}
AllowedIPs = {client_ip}/32
""")
        
        # Динамическое применение изменений через wg set
        try:
            # Получаем имя интерфейса из пути к конфигу
            interface = os.path.basename(CONF).replace('.conf', '')
            
            print(f"\n{Colors.CYAN}Пробуем применить изменения динамически...{Colors.ENDC}")
            
            # Создаём временный файл для PSK (для всех ОС)
            temp_psk_file = os.path.join(KEYS_DIR, f"{client_name}.psk.tmp")
            with open(temp_psk_file, 'w') as f:
                f.write(psk)
            
            # Применяем изменения с помощью wg set с файлом PSK
            wg_set_cmd = f"wg set {interface} peer {client_pub} preshared-key {temp_psk_file} allowed-ips {client_ip}/32"
            
            # Запускаем команду с повышенными привилегиями
            if os.name == 'nt':
                # В Windows используем PowerShell с повышенными привилегиями
                set_result = subprocess.run(["powershell", "Start-Process", "cmd", "-ArgumentList", f"/c {wg_set_cmd}", "-Verb", "RunAs"], 
                                           capture_output=True, text=True)
            else:
                # В Linux используем sudo
                set_result = subprocess.run(f"sudo {wg_set_cmd}", shell=True, capture_output=True, text=True)
            
            # Проверяем результат
            if set_result.returncode == 0:
                print(f"{Colors.GREEN}Изменения успешно применены динамически!{Colors.ENDC}")
            else:
                print(f"{Colors.WARNING}Не удалось применить изменения динамически: {set_result.stderr or set_result.stdout or 'Неизвестная ошибка'}{Colors.ENDC}")
                print(f"{Colors.WARNING}Изменения будут применены при следующем перезапуске WireGuard.{Colors.ENDC}")
            
            # Удаляем временный файл
            if os.path.exists(temp_psk_file):
                os.remove(temp_psk_file)
                
        except Exception as e:
            print(f"{Colors.WARNING}Не удалось применить изменения динамически: {str(e)}{Colors.ENDC}")
            print(f"{Colors.WARNING}Изменения будут применены при следующем перезапуске WireGuard.{Colors.ENDC}")
        
        # Создание клиентского конфига
        client_conf = f"""\
[Interface]
PrivateKey = {client_priv}
Address = {client_ip}/24
DNS = 1.1.1.1

[Peer]
PublicKey = {server_pub}
PresharedKey = {psk}
AllowedIPs = 10.8.0.0/24
Endpoint = {ENDPOINT}
"""
        
        # Сохранение конфига клиента
        ensure_keys_dir()
        with open(f"{KEYS_DIR}/{client_name}.conf", 'w') as f:
            f.write(client_conf)
        
        print(f"\n{Colors.GREEN}Клиент {Colors.BOLD}{client_name}{Colors.ENDC}{Colors.GREEN} добавлен с IP {Colors.BOLD}{client_ip}{Colors.ENDC}")
        print(f"{Colors.GREEN}Конфиг клиента сохранён в файле {Colors.BOLD}{KEYS_DIR}/{client_name}.conf{Colors.ENDC}")
        
        show_keys = input("\nХотите просмотреть ключи? (д/н): ").lower()
        if show_keys == 'д' or show_keys == 'y' or show_keys == 'да' or show_keys == 'yes':
            clear_screen()
            print_header()
            print(f"{Colors.BOLD}Ключи клиента {client_name}:{Colors.ENDC}\n")
            print(f"{Colors.CYAN}Приватный ключ: {Colors.BOLD}{client_priv}{Colors.ENDC}")
            print(f"{Colors.CYAN}Публичный ключ: {Colors.BOLD}{client_pub}{Colors.ENDC}")
            print(f"{Colors.CYAN}PSK: {Colors.BOLD}{psk}{Colors.ENDC}")
            print(f"\n{Colors.BOLD}Конфигурация:{Colors.ENDC}\n")
            print(f"{Colors.CYAN}{client_conf}{Colors.ENDC}")
            
    except Exception as e:
        print(f"{Colors.FAIL}Произошла ошибка: {str(e)}{Colors.ENDC}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def list_clients():
    print(f"{Colors.BOLD}Список клиентов{Colors.ENDC}\n")
    
    clients = get_all_clients()
    
    if not clients:
        print(f"{Colors.WARNING}Клиенты не найдены{Colors.ENDC}")
        input("\nНажмите Enter для возврата в меню...")
        return
    
    print(f"{Colors.CYAN}{'№':<3}{'Имя':<20}{'IP адрес':<15}{Colors.ENDC}")
    print("-" * 38)
    
    for i, (name, ip) in enumerate(clients, 1):
        print(f"{i:<3}{name:<20}{ip:<15}")
    
    print("\n" + "-" * 38)
    print(f"\nВсего клиентов: {len(clients)}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def delete_client():
    print(f"{Colors.BOLD}Удаление клиента{Colors.ENDC}\n")
    
    clients = get_all_clients()
    
    if not clients:
        print(f"{Colors.WARNING}Клиенты не найдены{Colors.ENDC}")
        input("\nНажмите Enter для возврата в меню...")
        return
    
    print(f"{Colors.CYAN}{'№':<3}{'Имя':<20}{'IP адрес':<15}{Colors.ENDC}")
    print("-" * 38)
    
    for i, (name, ip) in enumerate(clients, 1):
        print(f"{i:<3}{name:<20}{ip:<15}")
    
    print("\n" + "-" * 38)
    
    try:
        choice = input("\nВыберите номер клиента для удаления (или 0 для отмены): ")
        if not choice or choice == '0':
            return
        
        idx = int(choice) - 1
        if idx < 0 or idx >= len(clients):
            print(f"{Colors.FAIL}Некорректный номер клиента{Colors.ENDC}")
            input("\nНажмите Enter для возврата в меню...")
            return
        
        name, ip = clients[idx]
        confirm = input(f"Вы действительно хотите удалить клиента {name} ({ip})? (д/н): ").lower()
        if confirm != 'д' and confirm != 'y' and confirm != 'да' and confirm != 'yes':
            print(f"{Colors.WARNING}Отменено пользователем{Colors.ENDC}")
            input("\nНажмите Enter для возврата в меню...")
            return
        
        with open(CONF, 'r') as f:
            lines = f.readlines()
        
        # Поиск и удаление секции клиента
        new_lines = []
        i = 0
        while i < len(lines):
            if lines[i].strip() == f"# Client: {name}":
                # Пропускаем секцию клиента
                i += 1
                while i < len(lines) and not lines[i].strip().startswith("#"):
                    i += 1
            else:
                new_lines.append(lines[i])
                i += 1
        
        # Запись обновлённого конфига
        with open(CONF, 'w') as f:
            f.writelines(new_lines)
        
        # Удаление файла конфига клиента из каталога keys
        config_path = f"{KEYS_DIR}/{name}.conf"
        if os.path.exists(config_path):
            os.remove(config_path)
            print(f"\n{Colors.GREEN}Файл конфигурации {config_path} удален{Colors.ENDC}")
        
        # Находим публичный ключ клиента для динамического удаления
        try:
            client_pub = None
            
            # Попробуем найти публичный ключ в серверном конфиге
            with open(CONF, 'r') as f:
                server_conf = f.read()
                section_match = re.search(f'# Client: {name}.*?\\[Peer\\](.*?)(?=\\[|$)', server_conf, re.DOTALL)
                if section_match:
                    peer_section = section_match.group(1)
                    pub_key_match = re.search(r'PublicKey\s*=\s*(\S+)', peer_section)
                    if pub_key_match:
                        client_pub = pub_key_match.group(1)
                        
            # Если не нашли в серверном конфиге, попробуем получить из приватного ключа
            if not client_pub and os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    client_conf = f.read()
                    client_pub_match = re.search(r'PrivateKey\s*=\s*(\S+)', client_conf)
                    if client_pub_match:
                        client_priv = client_pub_match.group(1)
                        proc = subprocess.run(["wg", "pubkey"], input=client_priv+"\n", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        if proc.returncode == 0:
                            client_pub = proc.stdout.strip()
        except Exception as e:
            print(f"{Colors.WARNING}Не удалось найти публичный ключ клиента: {str(e)}{Colors.ENDC}")
            client_pub = None
        
        # Динамическое удаление через wg
        if client_pub:
            try:
                # Определяем имя интерфейса из пути к конфигу
                interface = os.path.basename(CONF).replace('.conf', '')
                
                print(f"\n{Colors.CYAN}Пробуем динамически удалить пира...{Colors.ENDC}")
                
                # Удаляем пира с помощью wg
                if os.name == 'nt':
                    remove_cmd = f"wg set {interface} peer {client_pub} remove"
                    subprocess.run(["powershell", "Start-Process", "cmd", "-ArgumentList", f"/c {remove_cmd}", "-Verb", "RunAs"], 
                                  capture_output=True, text=True)
                else:
                    remove_cmd = f"sudo wg set {interface} peer {client_pub} remove"
                    subprocess.run(remove_cmd, shell=True, capture_output=True, text=True)
                
                print(f"{Colors.GREEN}Пир динамически удален!{Colors.ENDC}")
            except Exception as e:
                print(f"{Colors.WARNING}Не удалось динамически удалить пира: {str(e)}{Colors.ENDC}")
                print(f"{Colors.WARNING}Изменения будут применены при следующем перезапуске WireGuard.{Colors.ENDC}")
        
        print(f"\n{Colors.GREEN}Клиент {Colors.BOLD}{name}{Colors.ENDC}{Colors.GREEN} успешно удален{Colors.ENDC}")
        
    except Exception as e:
        print(f"{Colors.FAIL}Произошла ошибка: {str(e)}{Colors.ENDC}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def show_client_keys():
    print(f"{Colors.BOLD}Просмотр ключей клиента{Colors.ENDC}\n")
    
    if not os.path.exists(KEYS_DIR) or not os.listdir(KEYS_DIR):
        print(f"{Colors.WARNING}Конфигурации клиентов не найдены в папке {KEYS_DIR}{Colors.ENDC}")
        input("\nНажмите Enter для возврата в меню...")
        return
    
    configs = [f for f in os.listdir(KEYS_DIR) if f.endswith('.conf')]
    
    print(f"{Colors.CYAN}{'№':<3}{'Имя клиента':<30}{Colors.ENDC}")
    print("-" * 33)
    
    for i, conf in enumerate(configs, 1):
        name = conf.replace('.conf', '')
        print(f"{i:<3}{name:<30}")
    
    print("\n" + "-" * 33)
    
    try:
        choice = input("\nВыберите номер клиента для просмотра ключей (или 0 для отмены): ")
        if not choice or choice == '0':
            return
        
        idx = int(choice) - 1
        if idx < 0 or idx >= len(configs):
            print(f"{Colors.FAIL}Некорректный номер клиента{Colors.ENDC}")
            input("\nНажмите Enter для возврата в меню...")
            return
        
        config_path = os.path.join(KEYS_DIR, configs[idx])
        client_name = configs[idx].replace('.conf', '')
        
        with open(config_path, 'r') as f:
            config = f.read()
        
        private_key_match = re.search(r'PrivateKey\s*=\s*(\S+)', config)
        if private_key_match:
            private_key = private_key_match.group(1)
        else:
            private_key = "Не найден"
        
        psk_match = re.search(r'PresharedKey\s*=\s*(\S+)', config)
        if psk_match:
            psk = psk_match.group(1)
        else:
            psk = "Не найден"
        
        server_pub_match = re.search(r'PublicKey\s*=\s*(\S+)', config)
        if server_pub_match:
            server_pub = server_pub_match.group(1)
        else:
            server_pub = "Не найден"
        
        # Получаем публичный ключ клиента из его приватного
        if private_key != "Не найден":
            proc = subprocess.run(["wg", "pubkey"], input=private_key+"\n", text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if proc.returncode == 0:
                client_pub = proc.stdout.strip()
            else:
                client_pub = "Не удалось получить"
        else:
            client_pub = "Не удалось получить"
        
        clear_screen()
        print_header()
        print(f"{Colors.BOLD}Ключи клиента {client_name}:{Colors.ENDC}\n")
        print(f"{Colors.CYAN}Приватный ключ клиента: {Colors.BOLD}{private_key}{Colors.ENDC}")
        print(f"{Colors.CYAN}Публичный ключ клиента: {Colors.BOLD}{client_pub}{Colors.ENDC}")
        print(f"{Colors.CYAN}Публичный ключ сервера: {Colors.BOLD}{server_pub}{Colors.ENDC}")
        print(f"{Colors.CYAN}PSK: {Colors.BOLD}{psk}{Colors.ENDC}")
        
        print(f"\n{Colors.BOLD}Полная конфигурация:{Colors.ENDC}\n")
        print(f"{Colors.CYAN}{config}{Colors.ENDC}")
        
    except Exception as e:
        print(f"{Colors.FAIL}Произошла ошибка: {str(e)}{Colors.ENDC}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def diagnose_connection():
    print(f"{Colors.BOLD}Диагностика проблем с подключением{Colors.ENDC}\n")
    
    # Проверка существования файла конфигурации
    if not os.path.exists(CONF):
        print(f"{Colors.FAIL}Ошибка: Конфигурационный файл {CONF} не найден!{Colors.ENDC}")
        input("\nНажмите Enter для возврата в меню...")
        return
    
    # Проверка формата файла конфигурации
    try:
        with open(CONF, 'r') as f:
            conf_content = f.read()
        
        # Проверка ключевых секций
        if "[Interface]" not in conf_content:
            print(f"{Colors.FAIL}Ошибка: В конфигурации отсутствует секция [Interface]{Colors.ENDC}")
        else:
            print(f"{Colors.GREEN}✓ Секция [Interface] найдена{Colors.ENDC}")
        
        # Проверка наличия приватного ключа
        if not re.search(r'PrivateKey\s*=\s*\S+', conf_content):
            print(f"{Colors.FAIL}Ошибка: Не найден приватный ключ в секции Interface{Colors.ENDC}")
        else:
            print(f"{Colors.GREEN}✓ Приватный ключ сервера найден{Colors.ENDC}")
        
        # Проверка Listen порта
        listen_port_match = re.search(r'ListenPort\s*=\s*(\d+)', conf_content)
        if not listen_port_match:
            print(f"{Colors.WARNING}Предупреждение: Не найден порт прослушивания (ListenPort){Colors.ENDC}")
        else:
            port = listen_port_match.group(1)
            print(f"{Colors.GREEN}✓ Сервер слушает порт {port}{Colors.ENDC}")
            
            # Проверка соответствия порта в Endpoint
            endpoint_port = ENDPOINT.split(':')[-1]
            if endpoint_port != port:
                print(f"{Colors.WARNING}Предупреждение: Порт в Endpoint ({endpoint_port}) не соответствует ListenPort ({port}){Colors.ENDC}")
        
        # Проверка клиентских подключений
        peers = re.findall(r'\[Peer\].*?(?=\[Peer\]|\Z)', conf_content, re.DOTALL)
        if not peers:
            print(f"{Colors.WARNING}Предупреждение: В конфигурации нет секций [Peer] (клиентов){Colors.ENDC}")
        else:
            print(f"{Colors.GREEN}✓ Найдено {len(peers)} клиентов в конфигурации{Colors.ENDC}")
            
            # Проверка ключей клиентов
            for i, peer in enumerate(peers, 1):
                pub_key_match = re.search(r'PublicKey\s*=\s*(\S+)', peer)
                if not pub_key_match:
                    print(f"{Colors.FAIL}Ошибка: У клиента #{i} отсутствует публичный ключ{Colors.ENDC}")
                
                allowed_ips_match = re.search(r'AllowedIPs\s*=\s*([0-9./,\s]+)', peer)
                if not allowed_ips_match:
                    print(f"{Colors.FAIL}Ошибка: У клиента #{i} отсутствуют разрешенные IP (AllowedIPs){Colors.ENDC}")
    
    except Exception as e:
        print(f"{Colors.FAIL}Ошибка при анализе конфигурации: {str(e)}{Colors.ENDC}")
    
    print(f"\n{Colors.BOLD}Проверка сетевых настроек:{Colors.ENDC}")
    
    # Проверка доступности порта
    endpoint_parts = ENDPOINT.split(':')
    if len(endpoint_parts) == 2:
        host, port = endpoint_parts
        print(f"\n{Colors.CYAN}Проверка доступности порта {port} на {host}...{Colors.ENDC}")
        
        # В Windows нельзя просто использовать nc, поэтому используем Python
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(3)
            sock.connect((host, int(port)))
            sock.close()
            print(f"{Colors.GREEN}✓ Порт {port} доступен{Colors.ENDC}")
        except Exception:
            print(f"{Colors.FAIL}✗ Порт {port} недоступен или заблокирован{Colors.ENDC}")
            print(f"{Colors.WARNING}Возможно, блокировка брандмауэром или неверный IP/порт{Colors.ENDC}")
    
    print(f"\n{Colors.BOLD}Советы по устранению ошибок:{Colors.ENDC}")
    print(f"1. {Colors.CYAN}Проверьте, что публичный ключ сервера правильно указан в конфиге клиента{Colors.ENDC}")
    print(f"2. {Colors.CYAN}Убедитесь, что порт UDP открыт на сервере (проверьте брандмауэр){Colors.ENDC}")
    print(f"3. {Colors.CYAN}Проверьте, что IP-адреса в AllowedIPs не конфликтуют{Colors.ENDC}")
    print(f"4. {Colors.CYAN}Проверьте работу DNS и маршрутизацию{Colors.ENDC}")
    print(f"5. {Colors.CYAN}Перезапустите службу WireGuard на сервере:{Colors.ENDC}")
    print(f"   {Colors.GREEN}sudo systemctl restart wg-quick@wg0{Colors.ENDC}")
    print(f"6. {Colors.CYAN}Проверьте статус соединения на сервере:{Colors.ENDC}")
    print(f"   {Colors.GREEN}sudo wg{Colors.ENDC}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def reload_wireguard():
    print(f"{Colors.BOLD}Перезагрузка конфигурации WireGuard{Colors.ENDC}\n")
    
    try:
        # Определяем имя интерфейса из пути к конфигу
        interface = os.path.basename(CONF).replace('.conf', '')
        
        print(f"Перезагружаем интерфейс {interface}...")
        
        # В зависимости от ОС используем разные команды
        if os.name == 'nt':
            # Для Windows используем PowerShell с повышенными привилегиями
            print(f"{Colors.CYAN}Останавливаем интерфейс...{Colors.ENDC}")
            stop_cmd = f"wireguard /uninstalltunnelservice {interface}"
            subprocess.run(["powershell", "Start-Process", "cmd", "-ArgumentList", f"/c {stop_cmd}", "-Verb", "RunAs"], 
                           capture_output=True, text=True)
            
            time.sleep(2)
            
            print(f"{Colors.CYAN}Запускаем интерфейс...{Colors.ENDC}")
            start_cmd = f"wireguard /installtunnelservice {CONF}"
            start_result = subprocess.run(["powershell", "Start-Process", "cmd", "-ArgumentList", f"/c {start_cmd}", "-Verb", "RunAs"], 
                                        capture_output=True, text=True)
        else:
            # Для Linux используем systemctl или wg-quick
            print(f"{Colors.CYAN}Перезагружаем интерфейс через systemd...{Colors.ENDC}")
            reload_cmd = f"sudo systemctl restart wg-quick@{interface}"
            reload_result = subprocess.run(reload_cmd, shell=True, capture_output=True, text=True)
            
            if reload_result.returncode != 0:
                print(f"{Colors.WARNING}Не удалось использовать systemd, пробуем wg-quick...{Colors.ENDC}")
                down_cmd = f"sudo wg-quick down {interface}"
                subprocess.run(down_cmd, shell=True, capture_output=True, text=True)
                
                time.sleep(1)
                
                up_cmd = f"sudo wg-quick up {interface}"
                reload_result = subprocess.run(up_cmd, shell=True, capture_output=True, text=True)
        
        print(f"{Colors.GREEN}Конфигурация WireGuard успешно перезагружена!{Colors.ENDC}")
        
    except Exception as e:
        print(f"{Colors.FAIL}Произошла ошибка при перезагрузке: {str(e)}{Colors.ENDC}")
    
    input("\nНажмите Enter для возврата в меню...")

@menu_decorator
def main_menu():
    while True:
        print(f"{Colors.BOLD}Главное меню:{Colors.ENDC}\n")
        print(f"1. {Colors.GREEN}Добавить нового клиента{Colors.ENDC}")
        print(f"2. {Colors.BLUE}Просмотреть список клиентов{Colors.ENDC}")
        print(f"3. {Colors.WARNING}Удалить клиента{Colors.ENDC}")
        print(f"4. {Colors.CYAN}Просмотреть ключи клиента{Colors.ENDC}")
        print(f"5. {Colors.BLUE}Диагностика подключения{Colors.ENDC}")
        print(f"6. {Colors.GREEN}Перезагрузить WireGuard{Colors.ENDC}")
        print(f"0. {Colors.FAIL}Выход{Colors.ENDC}")
        
        choice = input("\nВыберите действие: ")
        
        if choice == '1':
            add_client()
        elif choice == '2':
            list_clients()
        elif choice == '3':
            delete_client()
        elif choice == '4':
            show_client_keys()
        elif choice == '5':
            diagnose_connection()
        elif choice == '6':
            reload_wireguard()
        elif choice == '0':
            clear_screen()
            print_header()
            print(f"{Colors.GREEN}Спасибо за использование WireGuard Manager!{Colors.ENDC}")
            time.sleep(1)
            clear_screen()
            sys.exit(0)
        else:
            clear_screen()
            print_header()
            print(f"{Colors.FAIL}Некорректный выбор. Пожалуйста, повторите.{Colors.ENDC}")
            time.sleep(1)
            clear_screen()
            print_header()

if __name__ == "__main__":
    try:
        ensure_keys_dir()
        check_wg_command()
        main_menu()
    except KeyboardInterrupt:
        clear_screen()
        print("\nВыход из программы...")
        sys.exit(0)
