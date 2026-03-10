#!/bin/bash
set -euo pipefail

# --- Configuration Variables ---
DB_NAME="glpidb"
DB_USER="sitadmin"
DB_PASS="S3rv1c31T+"
GLPI_VER="11.0.6"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Updating system packages..."
apt update && apt upgrade -y

echo "Installing Apache, MariaDB, and PHP 8.3 dependencies..."
apt install -y apache2 mariadb-server libapache2-mod-php8.3 \
php8.3-cli php8.3-curl php8.3-gd php8.3-intl php8.3-mbstring \
php8.3-mysql php8.3-xml php8.3-zip php8.3-bz2 php8.3-ldap \
php8.3-bcmath php8.3-opcache php8.3-gmp php8.3-apcu wget tar

# --- Database Configuration ---
echo "Configuring MariaDB..."
systemctl enable --now mariadb

mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# --- GLPI Download and Extraction ---
echo "Downloading GLPI v$GLPI_VER..."
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/$GLPI_VER/glpi-$GLPI_VER.tgz
tar -xvzf glpi-$GLPI_VER.tgz -C /var/www/html/

# --- Permissions and Directory Setup ---
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html/glpi
chmod -R 755 /var/www/html/glpi

# --- Create missing .htaccess files ---
# GLPI 11 tarballs may not include .htaccess files; create them explicitly
# to ensure Apache mod_rewrite routes requests correctly.
echo "Creating .htaccess files..."

# Public-facing router: sends all non-file/dir requests to index.php
cat > /var/www/html/glpi/public/.htaccess <<'HTEOF'
RewriteEngine On

RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.php [QSA,L]
HTEOF

# Root-level: block direct access to everything outside /public
cat > /var/www/html/glpi/.htaccess <<'HTEOF'
RewriteEngine On
RewriteRule ^(.*)$ public/$1 [L]
HTEOF

chown www-data:www-data /var/www/html/glpi/public/.htaccess
chown www-data:www-data /var/www/html/glpi/.htaccess

# --- Apache Configuration ---
echo "Configuring Apache for GLPI 11..."
cat <<EOF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot /var/www/html/glpi/public
    ServerName localhost

    <Directory /var/www/html/glpi/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf || true
a2ensite glpi.conf
a2enmod rewrite
systemctl restart apache2

echo "-------------------------------------------------------"
echo "GLPI $GLPI_VER Installation complete!"
echo "Access GLPI at: http://$(hostname -I | awk '{print $1}')/install/install.php"
echo "Database: $DB_NAME | User: $DB_USER"
echo "-------------------------------------------------------"
echo "IMPORTANT: Complete the web installer at the URL above."
echo "When done, remove the installer immediately:"
echo "  sudo rm -rf /var/www/html/glpi/install/"
echo "-------------------------------------------------------"