#!/bin/bash
#script to install pelican panel on debian (11) and/or [partly working, use debian] ubuntu 20.04, 22.04, 24.04 DEV version

if ! command -v apt-get &> /dev/null; then
    echo "Only Ubuntu and Debian are currently supported."
    exit 1
fi


OS_INFO=$(cat /etc/os-release)
DEBIAN_VERSION=$(echo "$OS_INFO" | grep 'VERSION_ID' | cut -d '"' -f 2)
DEBIAN_PRETTY_NAME=$(echo "$OS_INFO" | grep 'PRETTY_NAME' | cut -d '"' -f 2)

if [ "$DEBIAN_VERSION" != "11" ]; then
    clear
    echo "'$DEBIAN_PRETTY_NAME' is not supported. If you still want to try wait 15 seconds."

    sleep 15

fi

validate_email() {
    if [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
        return 0
    else
        return 1
    fi
}

check_panel_reachability() {
    if curl --output /dev/null --silent --head --fail "https://$panel_domain"; then
        echo "Panel available."
    else
        echo "Panel unavailable. For any support contact vqbit on discord."
        exit 1
    fi
}

export TEXTDOMAIN=dialog
export LANGUAGE=en_EN.UTF-8

# Globale Konfigurationsvariablen
DOMAIN_REGEX="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$"
LOG_FILE="wlog.txt"
INSTALLER_URL="https://pterodactyl-installer.se"

# Funktion zur Generierung einer zufälligen dreistelligen Zahl
generate_random_number() {
    echo $((RANDOM % 900 + 100))
}

main_loop() {
    while true; do
        if [ -d "/var/www/pelican" ]; then
            MAIN_MENU=$(whiptail --title "Pelican Installer (dev version)" --menu "Pelican already installed.\nChoose:" 30 90 13 \
                "1" "Uninstall Pelican" \
                "2" "Cancel" 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ $exitstatus != 0 ]; then
                clear
                echo "Closed."
                echo ""
                exit
            fi

            clear
            case $MAIN_MENU in
                1) uninstall_pelican ;;
                2)
                   clear
                   echo ""
                   echo "INFO - - - - - - - - - -"
                   echo "Closed."
                   exit 0
                   ;;
            esac
        else
            echo "Success, continouing.."
            return
        fi
    done
}

install_wings() {
    clear
    echo "Redirecting"
    curl -sSfL https://raw.githubusercontent.com/v182/pelican-installer/dev/wings.sh | bash
    exit 0
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0  
    else
        return 1  
    fi
}


uninstall_pelican() {
    log_file="uninstall_pelican.txt"
    : > "$log_file" 


    if ! whiptail --title "Are you sure?" 10 50; then
        echo "Cancelled."
        return
    fi

    if whiptail --title "Do you want to keep all creates volumes/servers?" 10 50; then
        total_size=$(du -sb /var/lib/pelican/volumes/ | cut -f1)
        (cd /var/lib/pelican/volumes/ && tar -cf - . | pv -n -s "$total_size" | gzip > /volumes.tar.gz) 2>&1 | whiptail --gauge "Creating Backup.." 6 50 0
        if ! whiptail --title "Backup" --yesno "Backup created. continoue?" 10 50; then
            echo "Cancelled."
            return
        fi
    fi

    while true; do
        CONFIRMATION=$(whiptail --title "Confirmation" --inputbox "Please type 'Delete Pelican'" 10 50 3>&1 1>&2 2>&3)
        if [ "$CONFIRMATION" = "Delete Pelican" ]; then
            break
        else
            whiptail --title "Wrong." --msgbox "Try again." 10 50
        fi
    done

    progress=0
    {
        bash <(curl -s https://pterodactyl-installer.se) <<EOF 2>&1 | while IFS= read -r line; do
6
y
y
y
y
y
EOF
            echo "$line" >> "$log_file"
            case "$line" in
                *SUCCESS:\ Removed\ panel\ files.*)
                    progress=5 ;;
                *Removing\ cron\ jobs...*)
                    progress=10 ;;
                *SUCCESS:\ Removed\ cron\ jobs.*)
                    progress=20 ;;
                *Removing\ database...*)
                    progress=30 ;;
                *SUCCESS:\ Removed\ database\ and\ database\ user.*)
                    progress=40 ;;
                *Removing\ services...*)
                    progress=50 ;;
                *SUCCESS:\ Removed\ services.*)
                    progress=60 ;;
                *Removing\ docker\ containers\ and\ images...*)
                    progress=70 ;;
                *SUCCESS:\ Removed\ docker\ containers\ and\ images.*)
                    progress=80 ;;
                *Removing\ wings\ files...*)
                    progress=90 ;;
                *SUCCESS:\ Removed\ wings\ files.*)
                    progress=95 ;;
                *Thank\ you\ for\ using\ this\ script.*)
                    progress=100 ;;
            esac

            echo "XXX"
            echo "Deinstalling.."
            echo "XXX"
            echo $progress
        done
    } | whiptail --title "🗑️  Deinstallation" --gauge "Deinstalling" 6 50 0

    # Abschlussmeldung
    whiptail --title "Completed" --msgbox "Deleted successfully." 10 50
    clear
}


main_loop

recreate_user() {
    {
        echo "10"; sleep 1
        echo "Deleting Use..."
        cd /var/www/pelican && echo -e "1\n1\nyes" | php artisan p:user:delete
        echo "30"; sleep 1
        echo "Creating... With Mail: $admin_email With password: $user_password"
        cd /var/www/pelican && php artisan p:user:make --email="$admin_email" --username=admin --name-first=Admin --name-last=User --password="$user_password" --admin=1
        echo "100"; sleep 1
    } | whiptail --gauge "User creating" 8 50 0
}


isValidDomain() {
    DOMAIN_REGEX="^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if [[ $1 =~ $DOMAIN_REGEX ]]; then
        return 0
    else
        return 1
    fi
}

clear
clear
echo "Pelican Installation (inspired by the germandactyl installer (german ptero) from pavl21)"
sleep 3 

if [ "$(id -u)" != "0" ]; then
    echo "Please use root."
    exit 1
fi


clear
echo ""
echo ""
echo "STATUS - - - - - - - - - - - - - - -"
echo ""

show_spinner() {
    local pid=$1
    local delay=0.45
    local spinstr='|/-\\'
    local msg="Installing Dependencies.."
    while [ "$(ps a | awk '{print $1}' | grep -w $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  $msg" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
        for i in $(seq 1 $((${#msg} + 10))); do  
            printf " "
        done
        printf "\r"
    done
    printf "                                             \r"
}


(
    dpkg --configure -a
    apt-get update &&
    apt-get upgrade -y &&
    sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install -y whiptail dnsutils curl expect openssl bc certbot python3-certbot-nginx pv sudo wget
) > /dev/null 2>&1 &

PID=$!

show_spinner $PID

wait $PID
exit_status=$?


if [ $exit_status -ne 0 ]; then
    echo "A error spawned in.. contact vqbit on discord for support"
    exit $exit_status
fi

clear
echo ""
echo ""
echo "STATUS - - - - - - - - - - - - - - - -"
echo ""
echo "Installed Dependencies successfully"
sleep 2

IP_ADDRESS=$(hostname -I | awk '{print $1}')
SYSTEM_NAME=$(uname -o)

if [[ $IP_ADDRESS == 192.168.* ]] || [[ $IP_ADDRESS == 10.0.* ]] || ([[ $IP_ADDRESS == 172.16.* ]] && [[ $IP_ADDRESS != 172.32.* ]]); then
    # Sichere die aktuelle NEWT_COLORS Umgebungsvariable
    OLD_NEWT_COLORS=$NEWT_COLORS

    export NEWT_COLORS='
    root=,red
    window=,purple
    border=white,red
    textbox=white,purple
    button=black,white
    entry=,purple
    checkbox=,purple
    compactbutton=,purple
    '

    # Zeige das Whiptail-Fenster an
    if whiptail --title "Local Network (NR)" --yesno "Local Network neither supported nor recommended. Continoue?" 20 80; then
        echo "Loading.."
    else
        echo "Cancelled."
        exit 1
    fi

    export NEWT_COLORS=$OLD_NEWT_COLORS
else
    echo "Loading.."
    clear
fi


if whiptail --title "Pelican Install Script" --yesno "Pelican Installer by v182 (vqbit) inspired by germandactyl (german ptero) (by pavl21) - Cotinoue?


Continoue?" 22 70; then
    echo "Loading.."
else
    echo "STATUS - - - - - - - - - - - - - - - -"
    echo ""
    echo "Cancelled"
    exit 1
fi


CHOICE=$(whiptail --title "Pelican Installer" --menu "dev version" 15 60 4 \
"1" "Install Panel & Wings" \
"2" "Install Wings" 3>&1 1>&2 2>&3)

EXITSTATUS=$?

if [ $EXITSTATUS = 0 ]; then
  case $CHOICE in
    1)
      echo "Installing.."
      ;;
    2)
      install_wings
      exit 0
      ;;
  esac
else
  exit 0
fi

LOG_FILE="tmp.txt"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

clear

#!/bin/bash

# Überprüfe die CPU-Architektur
output=$(uname -m)
echo "Aktuelle CPU-Architektur: $output"

if [ "$output" != "x86_64" ]; then
    # Setze NEWT_COLORS nur für dieses spezifische Fenster
    OLD_NEWT_COLORS=$NEWT_COLORS
    export NEWT_COLORS='
    root=,red
    window=,purple
    border=white,purple
    textbox=white,purple
    button=black,white
    entry=,purple
    checkbox=,purple
    compactbutton=,purple
    '

    if whiptail --title "CPU not recommended" --yesno "Continoue?" 20 70; then
        echo
        echo "Loading.."
        cpu_arch_conflict=true
    else
        clear
        echo "STATUS - - - - - - - - - -"
        echo ""
        echo "Cancelled."
        export NEWT_COLORS=$OLD_NEWT_COLORS
        exit 0
    fi

    export NEWT_COLORS=$OLD_NEWT_COLORS
else
    echo "Loading.."
fi


while true; do
    panel_domain=$(whiptail --title "Pelican Installer" --inputbox "Panel FQDN?" 12 60 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo "Cancelled."
        exit 1
    fi

    if [[ $panel_domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        whiptail --title "Not a valid domain." --msgbox "Please use a valid one." 10 50
    fi
done

server_ip=$(hostname -I | awk '{print $1}')
dns_ip=$(dig +short $panel_domain)

if [ "$dns_ip" == "$server_ip" ]; then
    whiptail --title "Success, loading.." 8 78
else
    whiptail --title "Domain doesnt point to this machines IP address." 15 80
    exit 1
fi


validate_email() {
    if [[ $1 =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,10}$ ]]; then
        return 0
    else
        return 1
    fi
}

while true; do
    admin_email=$(whiptail --title "Pelican Installer" --inputbox "Input Email Address" 12 60 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo "Cancelled."
        exit 1
    fi

    if validate_email "$admin_email"; then
        break
    else
        whiptail --title "email not valid." --msgbox  "Input a valid email" 10 50
    fi
done

generate_userpassword() {
    < /dev/urandom tr -dc A-Za-z0-9 | head -c32
}

user_password=$(generate_userpassword)

generate_dbpassword() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c64
}

database_password=$(generate_dbpassword)

TITLE="Loading.."
MESSAGE="Installing.. this could take a bit.."
TOTAL_TIME=10
STEP_DURATION=$((TOTAL_TIME * 1000 / 100)) # in Millisekunden
{
    for ((i=100; i>=0; i--)); do
        echo $i
        sleep 0.05
    done
} | whiptail --gauge "$MESSAGE" 8 78 0

update_progress() {
    percentage=$1
    message=$2
    echo -e "XXX\n$percentage\n$message\nXXX"
}
monitor_progress() {
    highest_progress=0
    {
        while read line; do
            current_progress=0
            case "$line" in
                *"* Assume SSL? false"*)
                    update_progress 5 "Setting up all settings.." ;;
                *"Selecting previously unselected package apt-transport-https."*)
                    update_progress 10 "Starting Installation.." ;;
                *"Selecting previously unselected package mysql-common."*)
                    update_progress 15 "Installing MariaDB" ;;
                *"Unpacking php8.3-zip"*)
                    update_progress 20 "Installing PHP 8.3" ;;
                *"Created symlink /etc/systemd/system/multi-user.target.wants/mariadb.service → /lib/systemd/system/mariadb.service."*)
                    update_progress 25 "MariaDB wird eingerichtet..." ;;
                *"Created symlink /etc/systemd/system/multi-user.target.wants/php8.3-fpm.service → /lib/systemd/system/php8.1-fpm.service."*)
                    update_progress 30 "FPM installing" ;;
                *"Executing: /lib/systemd/systemd-sysv-install enable mariadb"*)
                    update_progress 35 "Setting up MariaDB" ;;
                *"* Installing composer.."*)
                    update_progress 40 "Installing Composer" ;;
                *"* Downloading pelican panel files .. "*)
                    update_progress 45 "Downloading Pelican Files.." ;;
                *"database/.gitignore"*)
                    update_progress 50 "DB Migrations..." ;;
                *"database/Seeders/eggs/"*)
                    update_progress 55 "Eggs.." ;;
                *"* Installing composer dependencies.."*)
                    update_progress 60 "Composer extensions installing.." ;;
                *"* Creating database user pelican..."*)
                    update_progress 65 "Creating DB.." ;;
                *"INFO  Running migrations."*)
                    update_progress 70 "Migrations werden gestartet..." ;;
                *"* Installing cronjob.. "*)
                    update_progress 75 "Cronjob setup.." ;;
                *"* Installing pteroq service.."*)
                    update_progress 80 "Backend.." ;;
                *"Saving debug log to /var/log/letsencrypt/letsencrypt.log"*)
                    update_progress 85 "SSL Setup.." ;;
                *"Congratulations! You have successfully enabled"*)
                    update_progress 90 "Certificate created.." ;;
                *"Searching Pelican"*)
                    update_progress 95 "Installing.. this could take a bit" ;;
                *"Success"*)
                    update_progress 100 "Closing.." ;;
            esac
            if [ "$current_progress" -gt "$highest_progress" ]; then
                highest_progress=$current_progress
                update_progress $highest_progress "Status..."
            fi
        done < <(tail -n 0 -f tmp.txt)
    } | whiptail --title "Pelican Panel installing" --gauge "Pelican Panel - Installation" 10 70 0
}


monitor_progress &
MONITOR_PID=$!


{
cd /
sudo add-apt-repository ppa:ondrej/php
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
sudo apt install -y php8.2 php8.2-gd php8.2-mysql php8.2-mbstring php8.2-bcmath php8.2-xml php8.2-curl php8.2-zip php8.2-intl php8.2-sqlite3 php8.2-fpm php8.2-redis composer nginx
Y
mkdir -p /var/www/pelican
cd /var/www/pelican
curl -Lo panel.tar.gz https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/
composer install --no-dev --optimize-autoloader
yes
php artisan p:environment:setup
php artisan p:environment:database
php artisan p:environment:mail
php artisan migrate --seed --force
php artisan p:user:make
sudo crontab -e && echo "* * * * * php /var/www/pelican/artisan schedule:run >> /dev/null 2>&1" | sudo crontab -u root -
chown -R www-data:www-data /var/www/pelican/* 
EOF
} >> tmp.txt 2>&1


{
    apt-get update && sudo apt-get install certbot python3-certbot-nginx -y
    systemctl stop nginx
    certbot --nginx -d $panel_domain --email $admin_email --agree-tos --non-interactive
    fuser -k 80/tcp
    fuser -k 443/tcp
    systemctl restart nginx
    curl -sSL https://install.germandactyl.de/ | sudo bash -s -- -v1.11.3
} >> tmp.txt 2>&1


kill $MONITOR_PID
sleep 1


whiptail --clear
clear
recreate_user


show_access_data() {
    whiptail --title "Details" --msgbox "Be sure to save these details.\n\nPanel: $panel_domain\n\n User: admin\n Email: $admin_email\n Password: $user_password \n\n" 22 80
}

clear
whiptail --title "Installation succeded" --msgbox "Pelican should be available now. Log in using the following details.\n\nas " 22 80


while true; do
    show_access_data

    if whiptail --title "Success" --yesno "User working?" 10 60; then
        if whiptail --title "Zugang geht?" --yesno "Funktionieren die Zugangsdaten?" 10 60; then
            if whiptail --title "Wings" --yesno "Install Wings?" 10 60; then
                clear
                install_wings
                exit 0
            else
                whiptail --title "Cancelled." --msgbox "Wings Installation was cancelled." 10 60
                exit 0
            fi
        else
            recreate_user
        fi
    else
        break
    fi
done

clear
echo "Done"
