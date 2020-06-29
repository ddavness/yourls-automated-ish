# Basic, automatic configuration of YOURLS

# Lock these files for now
chown root:root config-template.php
chown root:root mariadb-init.sql
chmod 600 config-template.php
chmod 600 mariadb-init.sql

apt update
apt install -y \
            php php-fpm php-cli php-mysql php-zip \ # PHP Dependencies
            php-gd php-mbstring php-curl php-xml \
            php-pear php-bcmath \
            mariadb-server mariadb-client \ # MariaDB/MySql
            openssl sed git # These are generally already installed but it's never a bad idea to make sure

echo "Generating system secrets..."
DB_PASSWORD=$(dd if=/dev/urandom bs=4096 count=1024 2> /dev/null |\
                 openssl sha3-512 -binary | openssl base64 |\
                 openssl sha3-256 | sed "s/(stdin)= //g")

COOKIE=$(dd if=/dev/urandom bs=2048 count=2048 2> /dev/null |\
                 openssl sha3-512 -hex | openssl base64 |\
                 openssl sha3-256 | sed "s/(stdin)= //g")

sed -i "s/___DATABASE_PASSWORD___/${DB_PASSWORD}/g" mariadb-init.sql
sed -i "s/___DATABASE_PASSWORD___/${DB_PASSWORD}/g" config-template.php
sed -i "s/___COOKIEKEY___/${COOKIE}/g" config-template.php

echo "Initializing databse..."

mysql < mariadb-init.sql

echo "Importing YOURLS and updating to latest released version..."
git pull --recurse-submodules
cd yourls
git pull origin master
git checkout $(git describe --tags --abbrev=0)
echo "YOURLS VERSION: $(git describe --tags --abbrev=0)"
cd ..

# WIP - User configuration here
