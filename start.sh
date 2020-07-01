#!/usr/bin/env bash

# Basic, automatic configuration of YOURLS

# Got root?
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run me as root!"
    exit 1
fi

START=$(pwd)

# Lock these files for now
chown root:root config-template.php
chown root:root mariadb-init.sql
chmod 600 config-template.php
chmod 600 mariadb-init.sql

apt update
apt install -y \
            php php-fpm php-cli php-mysql php-zip \
            php-gd php-mbstring php-curl php-xml \
            php-pear php-bcmath \
            mysql-server mysql-client \
            openssl sed jq unzip wget

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

# Fork the template and lock it
rm -f config.php
cp config-template.php config.php
chown root:root config.php
chmod 600 config.php

YOURLS_VERSION=$(curl --silent "https://api.github.com/repos/YOURLS/YOURLS/releases/latest" | jq -r .tag_name)
echo "Downloading YOURLS, version ${YOURLS_VERSION}"
rm -f "${YOURLS_VERSION}.zip"
wget "https://github.com/YOURLS/YOURLS/archive/${YOURLS_VERSION}.zip"

echo "Initializing databse..."
mysql < mariadb-init.sql

# WIP - User configuration here
echo "We're now going to configure the first user."
echo -n "Please input your username: "
read USER
echo -n "Please input your password: "
read -s PASSWORD_1
echo -n "(again): "
read -s PASSWORD_2

while [[ "${PASSWORD_1}" -ne "${PASSWORD_2}" ]]; do
    echo "Password mismatch! Please try again."
    echo -n "Please input your password: "
    read -s PASSWORD_1
    echo -n "(again): "
    read -s PASSWORD_2
done

sed -i "s/___USERNAME___/${USER}/g" config.php
sed -i "s/___USERPASSWORD___/${PASSWORD_1}/g" config.php

echo -n "Where do you want to unpack YOURLS? Specify a directory: "
read INSTALL_DIR

while [ ! -d ${INSTALL_DIR} ]; do
    echo -n "This is not a directory! Please specify a directory: "
    read INSTALL_DIR
done

"Unpacking into ${INSTALL_DIR}..."

rm -f "${INSTALL_DIR}/yourls.zip"
mv "${YOURLS_VERSION}.zip" "${INSTALL_DIR}/yourls.zip"
cd ${YOURLS_VERSION}
unzip yourls.zip
rm -f yourls.zip
mv YOURLS-${YOURLS_VERSION}/* .
rm -rf YOURLS-${YOURLS_VERSION}/

# Copy our template there and last minute patches
mv ${START}/config.php user/config.php
rm user/config-sample.php
mv sample-robots.txt robots.txt

chmod 666 user/config.php

echo "YOU'LL STILL NEED TO CONFIGURE YOUR WEBSERVER TO SERVE THE YOURLS DIRECTORY (NGINX/APACHE/WHATEVER)"
echo "ONCE YOU'RE DONE AND MANAGE TO LOG IN SUCCESSFULLY INTO THE ADMIN FOR THE FIRST TIME, PLEASE RUN THIS COMMAND:"
echo ""
echo "sudo chmod 644 $(pwd)/user/config.php"

cd ${START}
