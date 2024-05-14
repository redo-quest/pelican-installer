#!/bin/bash

# DO NOT USE THIS -- ALPHA

WINGS_PATH="/usr/local/bin/wings"

if [ -f "$WINGS_PATH" ]; then
    if whiptail --title "🚀 Wings already installed" --yesno "Status?" 10 60; then
        status_output=$(systemctl status wings)
        if [[ $status_output == *"Failed to start Pterodactyl Wings Daemon."* ]]; then
            whiptail --title "🔴 Wings Fehler" --msgbox "There was a issue. Restart?" 10 60
            sudo systemctl restart wings
            status_output=$(systemctl status wings)
            if [[ $status_output == *"Failed to start Pterodactyl Wings Daemon."* ]]; then
                whiptail --title "🔴 Wings Issue" --msgbox "Wings could not be started. Check logs and/or make ports free." 10 80
            else
                whiptail --title "🟢 Started" --msgbox "Wings were successfully started" 10 60
            fi
        elif [[ $status_output == *"inactive (dead)"* ]]; then
            sudo systemctl start wings
            status_output=$(systemctl status wings)
            if [[ $status_output == *"Active: active (running)"* ]]; then
                whiptail --title "🟢 Started" --msgbox "Wings were successfully started" 10 60
            fi
        else
            whiptail --title "🚀 Wings" --msgbox "Wings already installed" 10 60
            exit 0
        fi
    else
        whiptail --title "🚫 Cancelled" --msgbox "Exited script." 10 60
    fi
fi


LOG_FILE="wings-install.log"
> "$LOG_FILE"

integrate_wings() {
    local DOMAIN="$1"

    systemctl enable wings
    systemctl stop wings
    cd /var/www/pelican
    php artisan p:location:make --short=DE --long="Hauptnetz"

    while true; do
        if whiptail --title "Wings Integration" --yesno "Please create a node in the panel." 10 60; then
            whiptail --title "Node setup Assistant" --msgbox "In the node settings is a deploy command and a config.yml, its explained there how you can do it but choose one of those ways and come back here." 15 100

            if whiptail --title "Wings Integration" --yesno "Did you connect your node in the panel with wings?" 10 60; then
                if [ -f /etc/pterodactyl/config.yml ]; then
                    systemctl start wings
                    if whiptail --title "Wings Status" --yesno "Wings was rebooted." 10 60; then
                        whiptail --title "🟢 Pelican ready." --msgbox "Ready." 15 100
                        swap_question
                    else
                        break
                    fi
                else
                    whiptail --title "Wings Integration" --msgbox "/etc/pelican/config.yml not found" 10 60
                fi
            else
                continue
            fi
        else
            whiptail --title "Wings Integration" --msgbox "Integrate a node in your panel with wings." 10 70
        fi
    done
}


validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        local server_ip=$(hostname -I | awk '{print $1}')
        local dns_ip=$(dig +short $domain)
        if [[ "$dns_ip" == "$server_ip" ]]; then
            title="✅ Success"
            message="Loading.."
            whiptail --title "$title" --msgbox "$message" 10 60
            return 0
        else
            title="❌ Error"
            message="The domain that is being used does not point to this machine."
            whiptail --title "$title" --msgbox "$message" 10 60
            return 1
        fi
    else
        title="❌ Error"
        message="Not a valid domain."
        whiptail --title "$title" --msgbox "$message" 10 60
        return 1
    fi
}

validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        whiptail --title "Issue" --msgbox "Not a valid email." 10 60
        return 1
    fi
}

install_wings_with_script() {
    echo -e "1\nN\nN\ny\n$DOMAIN\ny\n$admin_email\ny\n$( [[ ! -d "/var/www/pelican" ]] && echo "Y" )" > inputs.txt
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh >> "$LOG_FILE" 2>&1 &
    PID_DOCKER=$!

    monitor_progress &
    PID_MONITOR=$!
    wait $PID_DOCKER

    kill $PID_MONITOR

 
    #bash <(curl -s https://pterodactyl-installer.se) < inputs.txt >> "$LOG_FILE" 2>&1
    #old

    rm inputs.txt

    whiptail --title "Wings Integration" --msgbox "Wings installed. I will assist you trough the setup process." 10 60

    integrate_wings
}






monitor_progress() {
    declare -A progress_messages=(
        ["+ sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apt-transport-https ca-certificates curl gnupg >/dev/null"]=15
        ["+ sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin >/dev/null"]=27
        ["* Retrieving release information..."]=30
        ["* Installing virt-what..."]=35
        ["* - will not log or share any IP-information with any third-party."]=48
        ["SetCreated symlink /etc/systemd/system/timers.target.wants/certbot.timer → /lib/systemd/system/certbot.timer."]=56
        ["* SUCCESS: Pterodactyl Wings downloaded successfully"]=72
        ["* SUCCESS: Installed systemd service!"]=79
        ["* Configuring LetsEncrypt.."]=81
        ["Plugins selected: Authenticator standalone, Installer None"]=86
        ["Requesting a certificate for wings.pavl21.de"]=97
        ["* Wings installation completed"]=99
    )


    {
        for ((i=0; i<=100; i++)); do
            sleep 1

            line=$(tail -n 1 "$LOG_FILE")
            for key in "${!progress_messages[@]}"; do
                if [[ "$line" == *"$key"* ]]; then
                    echo "${progress_messages[$key]}"
                    break
                fi
            done
        done
    } | whiptail --title "Wings installing" --gauge "This could take a bit" 8 78 0
}

# SWAP-Speicher zuweisen
swap_question() {
    whiptail --title "Swap" --yesno "Enable swap?" 10 60
    response=$?
    if [ $response -eq 0 ]; then
        size=$(whiptail --title "Swap" --inputbox "Please input the size in MB:" 10 60 3>&1 1>&2 2>&3)
        response=$?
        if [ $response -eq 0 ]; then
            if [[ $size =~ ^[0-9]+$ ]]; then
                sudo fallocate -l ${size}M /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
                whiptail --title "Created" --msgbox "Swap created" 10 60
                exit 0
            else
                whiptail --title "Issue" --msgbox "Not a valid input" 10 60
            fi
        else
            whiptail --title "Wings installed" --msgbox "Closing.." 10 60
            exit 0
        fi
    else
        exit 0
    fi
}


while true; do
    DOMAIN=$(whiptail --title "Domain" --inputbox "Domain for the Wings service" 10 70 3>&1 1>&2 2>&3)

    if [ -z "$DOMAIN" ]; then
        whiptail --title "Installation cancelled" --msgbox "Not a valid domain." 10 60
        exit 0
    elif ! validate_domain "$DOMAIN"; then
        continue
    fi

    admin_email=$(whiptail --title "Email" --inputbox "(For LetsEncrypt)" 17 80 3>&1 1>&2 2>&3)

    if [ -z "$admin_email" ]; then
        whiptail --title "Installation cancelled" --msgbox "Not a valid email." 10 70
        exit 0
    elif ! validate_email "$admin_email"; then
        continue
    fi

    install_wings_with_script
    break
done

