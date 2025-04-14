#!/bin/bash
#=====================================================================
# LEMP/LAMP Stack Automate
#=====================================================================
# Автор: Павлович Владислав - pavlovich.live
# Дата: 14 апреля 2025
# Версия: 1.0.0
#
# Описание: Этот скрипт автоматизирует развертывание и настройку
# LEMP или LAMP стека с оптимизацией производительности и функциями
# безопасности. Поддерживает дистрибутивы Ubuntu и CentOS.
#=====================================================================

# Строгий режим выполнения
set -e

# Цвета для лучшей читаемости
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Без цвета

# Лог-файл
LOG_FILE="/var/log/lemp_automate.log"

# Переменные конфигурации со значениями по умолчанию
WEB_SERVER="nginx"
PHP_VERSION="8.2"
DATABASE="mariadb"
DB_VERSION=""
DOMAIN=""
SITE_DIR=""
ENABLE_SSL=false
ENABLE_SWAP=false
SWAP_SIZE=2G
CREATE_DB=false
DB_NAME=""
DB_USER=""
DB_PASS=""
OS_TYPE=""
PACKAGE_MANAGER=""
SERVICE_MANAGER=""

#=====================================================================
# Служебные функции
#=====================================================================

log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} - ${message}" | tee -a "${LOG_FILE}"
}

log_success() {
    log "${GREEN}УСПЕШНО: $1${NC}"
}

log_info() {
    log "${BLUE}ИНФО: $1${NC}"
}

log_warning() {
    log "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: $1${NC}"
}

log_error() {
    log "${RED}ОШИБКА: $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

detect_os() {
    log_info "Определение операционной системы..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        
        case $OS_NAME in
            ubuntu)
                OS_TYPE="debian"
                PACKAGE_MANAGER="apt"
                SERVICE_MANAGER="systemctl"
                log_success "Обнаружена Ubuntu $OS_VERSION"
                ;;
            debian)
                OS_TYPE="debian"
                PACKAGE_MANAGER="apt"
                SERVICE_MANAGER="systemctl"
                log_success "Обнаружена Debian $OS_VERSION"
                ;;
            centos|rhel|rocky|almalinux)
                OS_TYPE="rhel"
                PACKAGE_MANAGER="yum"
                SERVICE_MANAGER="systemctl"
                log_success "Обнаружена CentOS/RHEL-based система $OS_VERSION"
                ;;
            *)
                log_error "Неподдерживаемая операционная система: $OS_NAME"
                exit 1
                ;;
        esac
    else
        log_error "Не удалось определить операционную систему"
        exit 1
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer
    
    if [[ "$default" == "y" ]]; then
        prompt="${prompt} [Д/н]"
    else
        prompt="${prompt} [д/Н]"
    fi
    
    read -p "$prompt " answer
    
    if [[ -z "$answer" ]]; then
        answer="$default"
    fi
    
    if [[ ${answer,,} == "д" || ${answer,,} == "y" || ${answer,,} == "да" || ${answer,,} == "yes" ]]; then
        return 0 # true
    else
        return 1 # false
    fi
}

#=====================================================================
# Функции установки компонентов
#=====================================================================

update_system() {
    log_info "Обновление системных пакетов..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt update && apt upgrade -y
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum update -y
    fi
    
    log_success "Система успешно обновлена"
}

install_dependencies() {
    log_info "Установка зависимостей..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt install -y curl wget gnupg2 ca-certificates lsb-release software-properties-common apt-transport-https
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum install -y curl wget gnupg2 ca-certificates epel-release
    fi
    
    log_success "Зависимости успешно установлены"
}

install_nginx() {
    log_info "Установка Nginx..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt install -y nginx
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum install -y nginx
    fi
    
    # Запуск и включение Nginx
    $SERVICE_MANAGER start nginx
    $SERVICE_MANAGER enable nginx
    
    log_success "Nginx успешно установлен и запущен"
}

install_apache() {
    log_info "Установка Apache..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt install -y apache2
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum install -y httpd
    fi
    
    # Запуск и включение Apache
    if [[ "$OS_TYPE" == "debian" ]]; then
        $SERVICE_MANAGER start apache2
        $SERVICE_MANAGER enable apache2
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        $SERVICE_MANAGER start httpd
        $SERVICE_MANAGER enable httpd
    fi
    
    log_success "Apache успешно установлен и запущен"
}

install_php() {
    log_info "Установка PHP ${PHP_VERSION}..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        # Добавление PPA для PHP
        if ! grep -q "^deb .*ppa:ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
            add-apt-repository -y ppa:ondrej/php
            apt update
        fi
        
        # Установка PHP и основных модулей
        apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-mysql \
            php${PHP_VERSION}-xml php${PHP_VERSION}-xmlrpc php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
            php${PHP_VERSION}-imagick php${PHP_VERSION}-cli php${PHP_VERSION}-dev php${PHP_VERSION}-imap \
            php${PHP_VERSION}-mbstring php${PHP_VERSION}-opcache php${PHP_VERSION}-soap php${PHP_VERSION}-zip \
            php${PHP_VERSION}-intl
            
        # Запуск и включение PHP-FPM
        $SERVICE_MANAGER start php${PHP_VERSION}-fpm
        $SERVICE_MANAGER enable php${PHP_VERSION}-fpm
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        # Добавление репозитория Remi для PHP
        yum install -y http://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
        yum module reset php -y
        yum module enable php:remi-${PHP_VERSION} -y
        
        # Установка PHP и основных модулей
        yum install -y php php-fpm php-common php-mysqlnd php-xml php-xmlrpc php-curl php-gd \
            php-imagick php-cli php-devel php-imap php-mbstring php-opcache php-soap php-zip php-intl
            
        # Запуск и включение PHP-FPM
        $SERVICE_MANAGER start php-fpm
        $SERVICE_MANAGER enable php-fpm
    fi
    
    log_success "PHP ${PHP_VERSION} успешно установлен"
}

install_mysql() {
    log_info "Установка MySQL..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        # Добавление репозитория MySQL, если указана версия
        if [[ -n "$DB_VERSION" ]]; then
            # Скачивание конфигурационного пакета через https
            if ! wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb; then
                log_warning "Не удалось скачать конфигурационный пакет MySQL. Будет использована версия из стандартного репозитория."
            else
                # Установка конфигурационного пакета
                DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.24-1_all.deb
                rm -f mysql-apt-config_0.8.24-1_all.deb
                apt update
            fi
        fi
        
        # Предустановка параметров для MySQL
        # Устанавливаем пароль root заранее для неинтерактивной установки
        debconf-set-selections <<< "mysql-server mysql-server/root_password password $DB_PASS"
        debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DB_PASS"
        
        # Установка MySQL сервера
        apt install -y mysql-server mysql-client
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        # Добавление репозитория MySQL, если указана версия
        if [[ -n "$DB_VERSION" ]]; then
            # Проверяем, существует ли уже репозиторий
            if ! rpm -q mysql80-community-release; then
                # Скачиваем и устанавливаем репозиторий
                if [[ -f /etc/redhat-release ]]; then
                    RHEL_VERSION=$(rpm -E %rhel)
                    if ! rpm -Uvh https://repo.mysql.com/mysql80-community-release-el${RHEL_VERSION}-1.noarch.rpm; then
                        log_warning "Не удалось добавить репозиторий MySQL. Попытка использования стандартного репозитория."
                    else
                        # Отключаем модуль MySQL, чтобы избежать конфликтов
                        yum module disable mysql -y
                    fi
                fi
            fi
        fi
        
        # Установка MySQL сервера
        yum install -y mysql-server mysql || yum install -y community-mysql-server community-mysql
    fi
    
    # Запуск и включение MySQL
    $SERVICE_MANAGER start mysql || $SERVICE_MANAGER start mysqld
    $SERVICE_MANAGER enable mysql || $SERVICE_MANAGER enable mysqld
    
    log_success "MySQL успешно установлен"
}

install_mariadb() {
    log_info "Установка MariaDB..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        # Добавление репозитория MariaDB, если указана версия
        if [[ -n "$DB_VERSION" ]]; then
            # Добавляем ключи для репозитория MariaDB
            apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
            
            # Добавляем репозиторий вручную
            if [[ -f /etc/lsb-release ]]; then
                # Ubuntu
                . /etc/lsb-release
                echo "deb [arch=amd64] https://mirror.mva-n.net/mariadb/repo/${DB_VERSION}/ubuntu ${DISTRIB_CODENAME} main" > /etc/apt/sources.list.d/mariadb.list
            else
                # Debian
                . /etc/os-release
                echo "deb [arch=amd64] https://mirror.mva-n.net/mariadb/repo/${DB_VERSION}/debian ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/mariadb.list
            fi
            
            # Обновляем индекс пакетов
            apt update
        fi
        
        # Установка MariaDB сервера
        apt install -y mariadb-server
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        # Добавление репозитория MariaDB, если указана версия
        if [[ -n "$DB_VERSION" ]]; then
            # Создаем конфигурацию репозитория вручную
            cat > /etc/yum.repos.d/MariaDB.repo << EOF
[mariadb]
name = MariaDB
baseurl = https://mirror.mva-n.net/mariadb/yum/${DB_VERSION}/rhel\$releasever-amd64
gpgkey=https://mirror.mva-n.net/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        fi
        
        # Установка MariaDB сервера
        yum install -y MariaDB-server MariaDB-client || yum install -y mariadb-server mariadb
    fi
    
    # Запуск и включение MariaDB
    $SERVICE_MANAGER start mariadb || $SERVICE_MANAGER start mysql
    $SERVICE_MANAGER enable mariadb || $SERVICE_MANAGER enable mysql
    
    log_success "MariaDB успешно установлен"
}

configure_database() {
    log_info "Настройка базы данных..."
    
    local db_cmd
    if [[ "$DATABASE" == "mysql" ]]; then
        db_cmd="mysql"
    else
        db_cmd="mariadb"
    fi
    
    # Безопасная установка
    if [[ "$DATABASE" == "mysql" ]]; then
        # Для MySQL
        mysql_secure_installation <<EOF

y
$DB_PASS
$DB_PASS
y
y
y
y
EOF
    else
        # Для MariaDB
        mysql_secure_installation <<EOF

y
$DB_PASS
$DB_PASS
y
y
y
y
EOF
    fi
    
    # Создание базы данных и пользователя, если запрошено
    if [[ "$CREATE_DB" == true ]]; then
        log_info "Создание базы данных $DB_NAME и пользователя $DB_USER..."
        
        $db_cmd -u root -p"$DB_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        
        log_success "База данных и пользователь успешно созданы"
    fi
}

configure_nginx() {
    log_info "Настройка Nginx для ${DOMAIN}..."
    
    # Резервное копирование конфигурации по умолчанию
    if [[ -f /etc/nginx/sites-available/default ]]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
    fi
    
    # Создание конфигурации сайта
    cat > /etc/nginx/sites-available/$DOMAIN.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    root ${SITE_DIR};
    
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # Конфигурация PHP-FPM
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Оптимизация
        fastcgi_buffer_size 16k;
        fastcgi_buffers 16 16k;
    }
    
    # Заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Запрет доступа к скрытым файлам
    location ~ /\.(?!well-known) {
        deny all;
    }
    
    # Включение сжатия gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    
    # Настройки кеширования
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
    
    # Настройки логирования
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
}
EOF
    
    # Создание символической ссылки для активации сайта
    if [[ -d /etc/nginx/sites-enabled ]]; then
        ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/
        
        # Удаление сайта по умолчанию, если он существует
        if [[ -f /etc/nginx/sites-enabled/default ]]; then
            rm -f /etc/nginx/sites-enabled/default
        fi
    fi
    
    # Создание директории сайта, если она не существует
    mkdir -p ${SITE_DIR}
    
    # Создание простого тестового файла
    cat > ${SITE_DIR}/index.php << EOF
<?php
    echo '<h1>Добро пожаловать на ${DOMAIN}!</h1>';
    echo '<p>Версия PHP: ' . phpversion() . '</p>';
    echo '<h2>Установленные модули PHP:</h2>';
    echo '<pre>';
    print_r(get_loaded_extensions());
    echo '</pre>';
?>
EOF
    
    # Установка правильных прав доступа
    chown -R www-data:www-data ${SITE_DIR}
    
    # Проверка конфигурации Nginx
    nginx -t
    
    # Перезагрузка Nginx
    $SERVICE_MANAGER reload nginx
    
    log_success "Nginx успешно настроен для ${DOMAIN}"
}

configure_apache() {
    log_info "Настройка Apache для ${DOMAIN}..."
    
    # Создание конфигурации сайта
    if [[ "$OS_TYPE" == "debian" ]]; then
        conf_file="/etc/apache2/sites-available/$DOMAIN.conf"
        
        cat > $conf_file << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot ${SITE_DIR}
    
    <Directory ${SITE_DIR}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Конфигурация PHP
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    # Заголовки безопасности
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Content-Type-Options "nosniff"
    Header set Referrer-Policy "no-referrer-when-downgrade"
    
    # Включение сжатия gzip
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css application/javascript application/json
    </IfModule>
    
    # Настройки кеширования
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 month"
        ExpiresByType image/jpeg "access plus 1 month"
        ExpiresByType image/gif "access plus 1 month"
        ExpiresByType image/png "access plus 1 month"
        ExpiresByType text/css "access plus 1 week"
        ExpiresByType application/javascript "access plus 1 week"
    </IfModule>
    
    # Настройки логирования
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF
        
        # Включение необходимых модулей
        a2enmod rewrite headers expires deflate proxy_fcgi
        
        # Включение сайта и отключение сайта по умолчанию
        a2ensite $DOMAIN.conf
        a2dissite 000-default.conf
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        conf_file="/etc/httpd/conf.d/$DOMAIN.conf"
        
        cat > $conf_file << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot ${SITE_DIR}
    
    <Directory ${SITE_DIR}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Конфигурация PHP
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:9000"
    </FilesMatch>
    
    # Заголовки безопасности
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    Header set X-Content-Type-Options "nosniff"
    Header set Referrer-Policy "no-referrer-when-downgrade"
    
    # Включение сжатия gzip
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css application/javascript application/json
    </IfModule>
    
    # Настройки кеширования
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType image/jpg "access plus 1 month"
        ExpiresByType image/jpeg "access plus 1 month"
        ExpiresByType image/gif "access plus 1 month"
        ExpiresByType image/png "access plus 1 month"
        ExpiresByType text/css "access plus 1 week"
        ExpiresByType application/javascript "access plus 1 week"
    </IfModule>
    
    # Настройки логирования
    ErrorLog /var/log/httpd/${DOMAIN}_error.log
    CustomLog /var/log/httpd/${DOMAIN}_access.log combined
</VirtualHost>
EOF
        
        # Включение необходимых модулей
        for mod in rewrite headers expires deflate proxy_fcgi; do
            if ! grep -q "LoadModule ${mod}_module" /etc/httpd/conf.modules.d/*.conf; then
                echo "LoadModule ${mod}_module modules/mod_${mod}.so" >> /etc/httpd/conf.modules.d/00-base.conf
            fi
        done
    fi
    
    # Создание директории сайта, если она не существует
    mkdir -p ${SITE_DIR}
    
    # Создание простого тестового файла
    cat > ${SITE_DIR}/index.php << EOF
<?php
    echo '<h1>Добро пожаловать на ${DOMAIN}!</h1>';
    echo '<p>Версия PHP: ' . phpversion() . '</p>';
    echo '<h2>Установленные модули PHP:</h2>';
    echo '<pre>';
    print_r(get_loaded_extensions());
    echo '</pre>';
?>
EOF
    
    # Установка правильных прав доступа
    if [[ "$OS_TYPE" == "debian" ]]; then
        chown -R www-data:www-data ${SITE_DIR}
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        chown -R apache:apache ${SITE_DIR}
    fi
    
    # Перезапуск Apache
    if [[ "$OS_TYPE" == "debian" ]]; then
        $SERVICE_MANAGER restart apache2
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        $SERVICE_MANAGER restart httpd
    fi
    
    log_success "Apache успешно настроен для ${DOMAIN}"
}

configure_php() {
    log_info "Оптимизация конфигурации PHP..."
    
    local php_ini
    if [[ "$OS_TYPE" == "debian" ]]; then
        php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        php_ini="/etc/php.ini"
    fi
    
    # Резервное копирование оригинального php.ini
    cp $php_ini ${php_ini}.bak
    
    # Обновление настроек PHP для лучшей производительности
    sed -i 's/memory_limit = .*/memory_limit = 256M/' $php_ini
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' $php_ini
    sed -i 's/post_max_size = .*/post_max_size = 64M/' $php_ini
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' $php_ini
    sed -i 's/;opcache.enable=.*/opcache.enable=1/' $php_ini
    sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=128/' $php_ini
    sed -i 's/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' $php_ini
    sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' $php_ini
    sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=60/' $php_ini
    sed -i 's/;opcache.fast_shutdown=.*/opcache.fast_shutdown=1/' $php_ini
    
    # Перезапуск PHP-FPM
    if [[ "$OS_TYPE" == "debian" ]]; then
        $SERVICE_MANAGER restart php${PHP_VERSION}-fpm
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        $SERVICE_MANAGER restart php-fpm
    fi
    
    log_success "PHP успешно оптимизирован"
}

configure_mysql_performance() {
    log_info "Оптимизация производительности MySQL/MariaDB..."
    
    local my_cnf
    if [[ "$DATABASE" == "mysql" ]]; then
        if [[ "$OS_TYPE" == "debian" ]]; then
            my_cnf="/etc/mysql/mysql.conf.d/mysqld.cnf"
        elif [[ "$OS_TYPE" == "rhel" ]]; then
            my_cnf="/etc/my.cnf"
        fi
    else
        if [[ "$OS_TYPE" == "debian" ]]; then
            my_cnf="/etc/mysql/mariadb.conf.d/50-server.cnf"
        elif [[ "$OS_TYPE" == "rhel" ]]; then
            my_cnf="/etc/my.cnf.d/server.cnf"
        fi
    fi
    
    # Резервное копирование оригинальной конфигурации
    cp $my_cnf ${my_cnf}.bak
    
    # Получение объема системной памяти
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    local innodb_buffer_pool_size=$(($mem_total/2))
    
    # Добавление настроек оптимизации
    cat >> $my_cnf << EOF

# Оптимизации производительности
innodb_buffer_pool_size = ${innodb_buffer_pool_size}M
innodb_log_file_size = 64M
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 2M
max_connections = 500
EOF
    
    # Перезапуск службы базы данных
    if [[ "$DATABASE" == "mysql" ]]; then
        $SERVICE_MANAGER restart mysql
    else
        $SERVICE_MANAGER restart mariadb
    fi
    
    log_success "Производительность базы данных оптимизирована"
}

#=====================================================================
# Функции безопасности
#=====================================================================

setup_firewall() {
    log_info "Настройка файервола..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        # Установка UFW, если еще не установлен
        apt install -y ufw
        
        # Установка политик по умолчанию
        ufw default deny incoming
        ufw default allow outgoing
        
        # Разрешение SSH (порт 22)
        ufw allow ssh
        
        # Разрешение HTTP и HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Включение UFW в неинтерактивном режиме
        echo "y" | ufw enable
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        # Установка и настройка firewalld
        yum install -y firewalld
        $SERVICE_MANAGER start firewalld
        $SERVICE_MANAGER enable firewalld
        
        # Разрешение SSH, HTTP и HTTPS
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        
        # Применение изменений
        firewall-cmd --reload
    fi
    
    log_success "Файервол успешно настроен"
}

setup_fail2ban() {
    log_info "Настройка Fail2Ban..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt install -y fail2ban
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum install -y fail2ban
    fi
    
    # Создание конфигурации для Fail2Ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true
EOF
    
    # Перезапуск Fail2Ban
    $SERVICE_MANAGER start fail2ban
    $SERVICE_MANAGER enable fail2ban
    
    log_success "Fail2Ban успешно настроен"
}

setup_ssl() {
    log_info "Настройка SSL с Certbot..."
    
    # Установка Certbot
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt install -y certbot
        
        if [[ "$WEB_SERVER" == "nginx" ]]; then
            apt install -y python3-certbot-nginx
            certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
        else
            apt install -y python3-certbot-apache
            certbot --apache -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
        fi
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum install -y certbot
        
        if [[ "$WEB_SERVER" == "nginx" ]]; then
            yum install -y python3-certbot-nginx
            certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
        else
            yum install -y python3-certbot-apache
            certbot --apache -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
        fi
    fi
    
    # Добавление автоматического обновления сертификатов
    echo "0 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
    
    log_success "SSL успешно настроен для ${DOMAIN}"
}

setup_swap() {
    log_info "Настройка файла подкачки (swap) размером ${SWAP_SIZE}..."
    
    # Проверка, существует ли уже swap
    if free | grep -q 'Swap'; then
        log_warning "Swap уже сконфигурирован. Пропускаем этот шаг."
        return
    fi
    
    # Создание swap файла
    fallocate -l ${SWAP_SIZE} /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Добавление swap в fstab для автоматического монтирования при загрузке
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    # Настройка параметров swap
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p
    
    log_success "Swap успешно настроен"
}

disable_directory_listing() {
    log_info "Отключение листинга директорий..."
    
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        # Для Nginx
        find /etc/nginx -type f -name "*.conf" -exec sed -i 's/autoindex on/autoindex off/g' {} \;
        $SERVICE_MANAGER reload nginx
    else
        # Для Apache
        if [[ "$OS_TYPE" == "debian" ]]; then
            find /etc/apache2 -type f -name "*.conf" -exec sed -i 's/Options Indexes/Options/g' {} \;
            $SERVICE_MANAGER reload apache2
        elif [[ "$OS_TYPE" == "rhel" ]]; then
            find /etc/httpd -type f -name "*.conf" -exec sed -i 's/Options Indexes/Options/g' {} \;
            $SERVICE_MANAGER reload httpd
        fi
    fi
    
    log_success "Листинг директорий успешно отключен"
}

#=====================================================================
# Функции очистки
#=====================================================================

cleanup_system() {
    log_info "Очистка системы..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        apt clean
        apt autoremove -y
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        yum clean all
        yum autoremove -y
    fi
    
    log_success "Система успешно очищена"
}

uninstall_stack() {
    log_info "Удаление установленных компонентов..."
    
    if [[ "$OS_TYPE" == "debian" ]]; then
        # Удаление веб-сервера
        if [[ "$WEB_SERVER" == "nginx" ]]; then
            apt purge -y nginx nginx-common
            rm -rf /etc/nginx
        else
            apt purge -y apache2 apache2-utils
            rm -rf /etc/apache2
        fi
        
        # Удаление PHP
        apt purge -y php*
        rm -rf /etc/php
        
        # Удаление базы данных
        if [[ "$DATABASE" == "mysql" ]]; then
            apt purge -y mysql-server mysql-client
            rm -rf /etc/mysql /var/lib/mysql
        else
            apt purge -y mariadb-server mariadb-client
            rm -rf /etc/mysql /var/lib/mysql
        fi
        
    elif [[ "$OS_TYPE" == "rhel" ]]; then
        # Удаление веб-сервера
        if [[ "$WEB_SERVER" == "nginx" ]]; then
            yum remove -y nginx
            rm -rf /etc/nginx
        else
            yum remove -y httpd
            rm -rf /etc/httpd
        fi
        
        # Удаление PHP
        yum remove -y php*
        rm -rf /etc/php.d /etc/php-fpm.d
        
        # Удаление базы данных
        if [[ "$DATABASE" == "mysql" ]]; then
            yum remove -y mysql mysql-server
            rm -rf /var/lib/mysql
        else
            yum remove -y mariadb mariadb-server
            rm -rf /var/lib/mysql
        fi
    fi
    
    # Удаление логов
    rm -f /var/log/lemp_automate.log
    
    log_success "Все компоненты успешно удалены"
}

#=====================================================================
# Интерактивные функции
#=====================================================================

prompt_web_server() {
    echo -e "${CYAN}=== Выбор веб-сервера ===${NC}"
    echo "1) Nginx (рекомендуется)"
    echo "2) Apache"
    read -p "Выберите веб-сервер [1-2] (по умолчанию: 1): " choice
    
    case $choice in
        2)
            WEB_SERVER="apache"
            ;;
        *)
            WEB_SERVER="nginx"
            ;;
    esac
    
    log_info "Выбран веб-сервер: ${WEB_SERVER}"
}

prompt_php_version() {
    echo -e "${CYAN}=== Выбор версии PHP ===${NC}"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.1"
    echo "4) PHP 8.2 (рекомендуется)"
    read -p "Выберите версию PHP [1-4] (по умолчанию: 4): " choice
    
    case $choice in
        1)
            PHP_VERSION="7.4"
            ;;
        2)
            PHP_VERSION="8.0"
            ;;
        3)
            PHP_VERSION="8.1"
            ;;
        *)
            PHP_VERSION="8.2"
            ;;
    esac
    
    log_info "Выбрана версия PHP: ${PHP_VERSION}"
}

prompt_database() {
    echo -e "${CYAN}=== Выбор СУБД ===${NC}"
    echo "1) MariaDB (рекомендуется)"
    echo "2) MySQL"
    read -p "Выберите СУБД [1-2] (по умолчанию: 1): " choice
    
    case $choice in
        2)
            DATABASE="mysql"
            ;;
        *)
            DATABASE="mariadb"
            ;;
    esac
    
    log_info "Выбрана СУБД: ${DATABASE}"
    
    # Запрос версии СУБД
    echo -e "${CYAN}=== Версия СУБД ===${NC}"
    echo "Укажите конкретную версию ${DATABASE} (например: 10.6 для MariaDB или 8.0 для MySQL)"
    echo "Оставьте пустым для использования версии из репозитория по умолчанию"
    read -p "Версия ${DATABASE}: " DB_VERSION
    
    if [[ -n "$DB_VERSION" ]]; then
        log_info "Выбрана версия ${DATABASE}: ${DB_VERSION}"
    else
        log_info "Будет использована версия ${DATABASE} из репозитория по умолчанию"
    fi
}

prompt_domain() {
    echo -e "${CYAN}=== Настройка домена ===${NC}"
    read -p "Введите доменное имя (например, example.com): " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="localhost"
        log_info "Доменное имя не указано, будет использован localhost"
    else
        log_info "Указано доменное имя: ${DOMAIN}"
    fi
    
    # Запрос директории сайта
    read -p "Введите путь к директории сайта (по умолчанию: /var/www/${DOMAIN}): " SITE_DIR
    
    if [[ -z "$SITE_DIR" ]]; then
        SITE_DIR="/var/www/${DOMAIN}"
    fi
    
    log_info "Директория сайта: ${SITE_DIR}"
}

prompt_db_credentials() {
    echo -e "${CYAN}=== Настройка базы данных ===${NC}"
    
    # Запрос на создание базы данных
    if prompt_yes_no "Создать базу данных и пользователя?" "y"; then
        CREATE_DB=true
        
        # Имя базы данных
        read -p "Введите имя базы данных (по умолчанию: ${DOMAIN//./_}): " DB_NAME
        if [[ -z "$DB_NAME" ]]; then
            DB_NAME="${DOMAIN//./_}"
        fi
        
        # Имя пользователя базы данных
        read -p "Введите имя пользователя базы данных (по умолчанию: ${DB_NAME}): " DB_USER
        if [[ -z "$DB_USER" ]]; then
            DB_USER="${DB_NAME}"
        fi
        
        # Пароль пользователя базы данных
        read -p "Введите пароль пользователя базы данных (нажмите Enter для генерации): " DB_PASS
        if [[ -z "$DB_PASS" ]]; then
            DB_PASS=$(openssl rand -base64 12)
            echo "Сгенерирован пароль: ${DB_PASS}"
        fi
        
        log_info "Будут созданы: БД ${DB_NAME}, пользователь ${DB_USER}"
    else
        CREATE_DB=false
        
        # Всё равно нужен пароль root для безопасной установки MySQL/MariaDB
        read -p "Введите пароль для root пользователя базы данных (нажмите Enter для генерации): " DB_PASS
        if [[ -z "$DB_PASS" ]]; then
            DB_PASS=$(openssl rand -base64 12)
            echo "Сгенерирован пароль: ${DB_PASS}"
        fi
        
        log_info "База данных и пользователь не будут созданы"
    fi
}

prompt_ssl() {
    echo -e "${CYAN}=== Настройка SSL ===${NC}"
    
    if [[ "$DOMAIN" != "localhost" ]]; then
        if prompt_yes_no "Настроить SSL с Let's Encrypt для ${DOMAIN}?" "y"; then
            ENABLE_SSL=true
            log_info "SSL будет настроен для ${DOMAIN}"
        else
            ENABLE_SSL=false
            log_info "SSL не будет настроен"
        fi
    else
        log_info "SSL нельзя настроить для localhost, пропускаем..."
        ENABLE_SSL=false
    fi
}

prompt_swap() {
    echo -e "${CYAN}=== Настройка файла подкачки (swap) ===${NC}"
    
    # Получение информации о памяти
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    
    if [[ $mem_total -lt 2048 ]]; then
        echo "У вас всего ${mem_total}MB оперативной памяти."
        if prompt_yes_no "Настроить файл подкачки (swap)?" "y"; then
            ENABLE_SWAP=true
            
            read -p "Введите размер swap-файла (по умолчанию: 2G): " swap_input
            if [[ -n "$swap_input" ]]; then
                SWAP_SIZE="$swap_input"
            fi
            
            log_info "Будет создан swap-файл размером ${SWAP_SIZE}"
        else
            ENABLE_SWAP=false
            log_info "Swap-файл не будет создан"
        fi
    else
        log_info "У вас достаточно оперативной памяти (${mem_total}MB). Swap-файл не требуется."
        ENABLE_SWAP=false
    fi
}

#=====================================================================
# Основная функция
#=====================================================================

display_banner() {
    echo -e "${GREEN}"
    echo "  _     ______ __  __ _____    _____ _             _      "
    echo " | |   |  ____|  \/  |  __ \  / ____| |           | |     "
    echo " | |   | |__  | \  / | |__) || (___ | |_ __ _  ___| | __  "
    echo " | |   |  __| | |\/| |  ___/  \___ \| __/ _\` |/ __| |/ /  "
    echo " | |___| |____| |  | | |      ____) | || (_| | (__|   <   "
    echo " |_____|______|_|  |_|_|     |_____/ \__\__,_|\___|_|\_\  "
    echo -e "${NC}"
    echo "  Автоматическое развертывание LEMP/LAMP стека"
    echo "  Версия: 1.0.0"
    echo "  ------------------------------------------------"
    echo ""
}

display_summary() {
    echo -e "${CYAN}=== Сводка настроек ===${NC}"
    echo "Веб-сервер:        ${WEB_SERVER}"
    echo "Версия PHP:        ${PHP_VERSION}"
    echo "СУБД:              ${DATABASE} ${DB_VERSION}"
    echo "Домен:             ${DOMAIN}"
    echo "Директория сайта:  ${SITE_DIR}"
    
    if [[ "$CREATE_DB" == true ]]; then
        echo "База данных:       ${DB_NAME}"
        echo "Пользователь БД:   ${DB_USER}"
        echo "Пароль БД:         ${DB_PASS}"
    fi
    
    echo "Настроить SSL:     $(if [[ "$ENABLE_SSL" == true ]]; then echo "Да"; else echo "Нет"; fi)"
    echo "Настроить swap:    $(if [[ "$ENABLE_SWAP" == true ]]; then echo "Да (${SWAP_SIZE})"; else echo "Нет"; fi)"
    echo ""
    
    if prompt_yes_no "Продолжить установку с этими настройками?" "y"; then
        return 0
    else
        log_error "Установка отменена пользователем"
        exit 1
    fi
}

main() {
    # Проверка прав root
    check_root
    
    # Создание лог-файла
    touch "${LOG_FILE}"
    
    # Отображение баннера
    display_banner
    
    # Определение ОС
    detect_os
    
    # Интерактивный ввод настроек
    prompt_web_server
    prompt_php_version
    prompt_database
    prompt_domain
    prompt_db_credentials
    prompt_ssl
    prompt_swap
    
    # Отображение и подтверждение настроек
    display_summary
    
    # Обновление системы
    update_system
    
    # Установка зависимостей
    install_dependencies
    
    # Установка веб-сервера
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        install_nginx
    else
        install_apache
    fi
    
    # Установка PHP
    install_php
    
    # Установка базы данных
    if [[ "$DATABASE" == "mysql" ]]; then
        install_mysql
    else
        install_mariadb
    fi
    
    # Настройка базы данных
    configure_database
    
    # Настройка веб-сервера
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        configure_nginx
    else
        configure_apache
    fi
    
    # Оптимизация PHP
    configure_php
    
    # Оптимизация базы данных
    configure_mysql_performance
    
    # Настройка файервола
    setup_firewall
    
    # Настройка Fail2Ban
    setup_fail2ban
    
    # Отключение листинга директорий
    disable_directory_listing
    
    # Настройка SSL, если запрошено
    if [[ "$ENABLE_SSL" == true ]]; then
        setup_ssl
    fi
    
    # Настройка swap, если запрошено
    if [[ "$ENABLE_SWAP" == true ]]; then
        setup_swap
    fi
    
    # Очистка системы
    cleanup_system
    
    log_success "=================================================="
    log_success "      Установка LEMP/LAMP стека завершена!        "
    log_success "=================================================="
    
    echo -e "${GREEN}Установка завершена!${NC}"
    echo "Веб-сервер:        ${WEB_SERVER}"
    echo "Версия PHP:        ${PHP_VERSION}"
    echo "СУБД:              ${DATABASE} ${DB_VERSION}"
    echo "Домен:             ${DOMAIN}"
    echo "Директория сайта:  ${SITE_DIR}"
    
    if [[ "$CREATE_DB" == true ]]; then
        echo -e "${YELLOW}Информация о базе данных:${NC}"
        echo "База данных:       ${DB_NAME}"
        echo "Пользователь БД:   ${DB_USER}"
        echo "Пароль БД:         ${DB_PASS}"
        echo -e "${YELLOW}ВАЖНО: Сохраните эти данные в безопасном месте!${NC}"
    fi
    
    echo ""
    echo "Вы можете просмотреть лог установки: ${LOG_FILE}"
    echo ""
    
    if [[ "$DOMAIN" != "localhost" ]]; then
        echo "Ваш сайт доступен по адресу: http://${DOMAIN}"
        if [[ "$ENABLE_SSL" == true ]]; then
            echo "Защищенный доступ: https://${DOMAIN}"
        fi
    else
        echo "Ваш сайт доступен по адресу: http://localhost"
    fi
    
    echo ""
    echo -e "${GREEN}Спасибо за использование скрипта LEMP/LAMP Stack Automate!${NC}"
}

#=====================================================================
# Дополнительная функция для удаления всего стека
#=====================================================================

show_help() {
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Без параметров: Запуск в интерактивном режиме"
    echo ""
    echo "Опции:"
    echo "  --uninstall    Удаление всех установленных компонентов"
    echo "  --help         Показать эту справку"
    echo ""
}

# Обработка параметров командной строки
if [[ $# -gt 0 ]]; then
    case "$1" in
        --uninstall)
            check_root
            detect_os
            if prompt_yes_no "Вы уверены, что хотите удалить все компоненты LEMP/LAMP стека?" "n"; then
                uninstall_stack
            else
                echo "Удаление отменено."
            fi
            exit 0
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестный параметр: $1"
            show_help
            exit 1
            ;;
    esac
fi

# Запуск основной функции
main