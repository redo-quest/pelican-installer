#!/bin/sh

echo "Install Process.."

options=("Proceed" "Cancel")

PS3="Enter your choice: "
select opt in "${options[@]}"

do
  
            echo "Installation will proceed"
            do_install
        
done

do_install() {
cd /
sudo add-apt-repository ppa:ondrej/php
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
sudo apt install -y php8.2 php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml php8.2-curl php8.2-zip php8.2-intl php8.2-sqlite3 php8.2-fpm php8.2-redis
mkdir -p /var/www/pelican
cd /var/www/pelican
curl -Lo panel.tar.gz https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/
composer install --no-dev --optimize-autoloader
php artisan p:environment:setup
php artisan p:environment:database
php artisan p:environment:mail
php artisan migrate --seed --force
echo "Now you will create a user (Passwords must have 8 charactes, mixed case and at least one number)"
php artisan p:user:make
sudo crontab -e && echo "* * * * * php /var/www/pelican/artisan schedule:run >> /dev/null 2>&1" | sudo crontab -u root -
chown -R www-data:www-data /var/www/pelican/* 
echo "Proceed.."
}
