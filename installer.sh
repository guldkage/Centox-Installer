#!/bin/bash
#!/usr/bin/env bash

########################################################################
#                                                                      #
#            Centox Installer                                          #
#            Copyright 2022, Malthe K, <me@malthe.cc> hej              # 
#                                                                      #
#  This script is not associated with the official Centox Github       #
#  You may not remove this line                                        #
#                                                                      #
########################################################################

### VARIABLES ###

dist="$(. /etc/os-release && echo "$ID")"

### OUTPUTS ###

function trap_ctrlc ()
{
    echo "Bye!"
    exit 2
}
trap "trap_ctrlc" 2

warning(){
    echo -e '\e[31m'"$1"'\e[0m';

}

### CHECKS ###

if [[ $EUID -ne 0 ]]; then
    echo ""
    echo "[!] Sorry, but you need to be root to run this script."
    echo "Most of the time this can be done by typing sudo su in your terminal"
    exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
    echo ""
    echo "[!] cURL is required to run this script."
    echo "To proceed, please install cURL on your machine."
    echo ""
    echo "Debian based systems: apt install curl"
    exit 1
fi

### CODE ###

### CENTOX - INSTALL ###

centox_finish(){
    clear
    cd
    echo -e "Summary of the installation\n\nCentox URL: $FQDN\nCentox Port: $PORT\nDiscord Client ID: $DISCORD_ID\nDiscord Client Secret: $DISCORD_SECRET\nCentox Redirect URI: $DISCORD_REDIRECTURI\nDiscord owner ID: $DISCORD_OWNERID\n\nCentox Display Name: $CENTOX_NAME\nCentox Logo URL: $CENTOX_LOGO_URL\n$CENTOX_FAVICON_URL\n$CENTOX_DESCRIPTION\nCentox Keywords: $CENTOX_KEYWORDS" >> centox_credentials.txt

    echo "[!] Installation of Centox done"
    echo ""
    echo "    Summary of the installation" 
    echo "    Centox URL: $FQDN"
    echo "    Centox Port: $PORT"
    echo "    Discord Client ID: $DISCORD_ID"
    echo "    Discord Client Secret: $DISCORD_SECRET"
    echo "    Centox Redirect URI: $DISCORD_REDIRECTURI"
    echo "    Discord owner ID: $DISCORD_OWNERID"
    echo ""
    echo "    Centox Display Name: $CENTOX_NAME"
    echo "    Centox Logo URL: $CENTOX_LOGO_URL"
    echo "    Centox Favicon URL: $CENTOX_FAVICON_URL"
    echo "    Centox Description: $CENTOX_DESCRIPTION"
    echo "    Centox Keywords: $CENTOX_KEYWORDS"
    echo "" 
    echo "    Database username and password can be found in"
    echo "    .env file in /var/www/$FQDN/centox/.env"
    echo "" 
    echo "    These credentials has been saved in a file called" 
    echo "    centox_credentials.txt in your current directory"
    echo ""
}


centox_install(){
    clear
    apt update
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    apt-get install -y mongodb nginx certbot nodejs
    systemctl stop nginx &&  certbot certonly --standalone -d $FQDN --staple-ocsp --no-eff-email -m $EMAIL --agree-tos
    systemctl restart nginx
    npm i -g yarn

    cd
    mkdir /var/www/$FQDN
    cd /var/www/$FQDN
    git clone https://github.com/simonmaribo/centox.git
    cd centox
    yarn install

    CENTOX_DATABASE=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1`
    CENTOX_USERNAME=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
    CENTOX_USER_PASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    CENTOX_SECRET=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    mongo --eval 'db = db.getSiblingDB("centox_$CENTOX_DATABASE"); db.createUser({ user: "$CENTOX_USERNAME", pwd: "$CENTOX_USER_PASSWORD", roles: ["readWrite"] })'

    rm .env.example config.json
    wget https://raw.githubusercontent.com/guldkage/centox-installer/main/.env .env
    wget https://raw.githubusercontent.com/guldkage/centox-installer/main/config.json config.json

    sed -i -e "s@<mongodb_username>@${CENTOX_USERNAME}@g" .env
    sed -i -e "s@<mongodb_password>@${CENTOX_USER_PASSWORD}@g" .env
    sed -i -e "s@<mongodb_database>@${CENTOX_DATABASE}@g" .env
    sed -i -e "s@<centox_port>@${PORT}@g" .env
    sed -i -e "s@<centox_secret>@${CENTOX_SECRET}@g" .env

    sed -i -e "s@<centox_discordsecret>@${DISCORD_SECRET}@g" .env
    sed -i -e "s@<centox_discordid>@${DISCORD_ID}@g" .env
    sed -i -e "s@<centox_discorduri>@${DISCORD_REDIRECTURI}@g" .env
    sed -i -e "s@<centox_ownerid>@${DISCORD_OWNERID}@g" .env

    sed -i -e "s@<centox_title>@${CENTOX_NAME}@g" config.json
    sed -i -e "s@<centox_faviconurl>@${CENTOX_FAVICON_URL}@g" config.json
    sed -i -e "s@<centox_keywords>@${CENTOX_KEYWORDS}@g" config.json
    sed -i -e "s@<centox_description>@${CENTOX_DESCRIPTION}@g" config.json
    sed -i -e "s@<centox_url>@${FQDN}@g" config.json
    sed -i -e "s@<centox_logourl>@${CENTOX_LOGO_URL}@g" config.json

    yarn configure
    yarn build
    wget https://raw.githubusercontent.com/guldkage/centox-installer/main/centox.service /etc/systemd/system/centox_$FQDN.service
    sed -i -e "s@<centox_fqdn>@${FQDN}@g" /etc/systemd/system/centox_$FQDN.service
    systemctl enable centox_$FQDN --now

    wget https://raw.githubusercontent.com/guldkage/centox-installer/main/centox.conf /etc/nginx/sites-enabled/centox_$FQDN.conf
    sed -i -e "s@<centox_fqdn>@${FQDN}@g" /etc/nginx/sites-enabled/centox_$FQDN.conf
    sed -i -e "s@<centox_port>@${PORT}@g" /etc/nginx/sites-enabled/centox_$FQDN.conf
    systemctl restart nginx
    centox_finish
}

### CONFIGURATION ###

send_summary(){
    clear
    echo ""
    echo "[!] Summary:"
    echo "    Centox URL: $FQDN"
    echo "    Centox Port: $PORT"
    echo "    Discord Client ID: $DISCORD_ID"
    echo "    Discord Client Secret: $DISCORD_SECRET"
    echo "    Centox Redirect URI: $DISCORD_REDIRECTURI"
    echo "    Discord owner ID: $DISCORD_OWNERID"
    echo ""
    echo "    Centox Display Name: $CENTOX_NAME"
    echo "    Centox Logo URL: $CENTOX_LOGO_URL"
    echo "    Centox Favicon URL: $CENTOX_FAVICON_URL"
    echo "    Centox Description: $CENTOX_DESCRIPTION"
    echo "    Centox Keywords: $CENTOX_KEYWORDS"
    echo ""
}

centox(){
    send_summary
    echo "[!] Please enter URL of your upcoming Centox installation"
    read -r FQDN
    [ -z "$FQDN" ] && echo "FQDN can't be empty."
    IP=$(dig +short myip.opendns.com @resolver2.opendns.com -4)
    DOMAIN=$(dig +short ${FQDN})
    if [ "${IP}" != "${DOMAIN}" ]; then
        exit 0
        echo "Your FQDN does not resolve to the IP of this machine. The script cannot continue."
    else
        send_summary
        echo "[!] Please enter your email. It will be shared with Lets Encrypt to secure your Centox installation with SSL."
        read -r EMAIL
        centox_port
    fi
}

centox_ownerID(){
    send_summary
    echo "[!] Please enter your Discord ID so you can get automatic admin on your forum."
    read -r DISCORD_OWNERID
    centox_displayname
}

centox_redirectURI(){
    send_summary
    echo "[!] Please enter discord redirect URI. The correct way to enter this is: https://${FQDN}/login"
    echo "[!] Without placeholder: https://<your URL to Centox>/login"
    read -r DISCORD_REDIRECTURI
    centox_ownerID
}

centox_secret(){
    send_summary
    echo "[!] Please enter discord client secret for discord login."
    read -r DISCORD_SECRET
    centox_redirectURL
}

centox_id(){
    send_summary
    echo "[!] Please enter discord client ID for discord login."
    read -r DISCORD_ID
    centox_secret
}

centox_port(){
    send_summary
    echo "[!] Please enter your desired port to run Centox on. If you dont use port 8080 to anything, you can select that."
    read -r PORT
    centox_id
}

### centox name config ###

centox_start(){
    send_summary
    echo "[!] This is your summary for Centox Installation. All info must be correct or else the script can fail and possible damage this system. Please only continue if everything is correct. This script is not responsible for any damages."
    echo ""
    echo "[!] Do you wish to continue?"
    echo "(Y/N)"
    read -r CONFIRM_START

    if [[ "$CONFIRM_START" =~ [Yy] ]]; then
        echo ""
        echo "[!] Installation starting.."
        sleep 2s
        centox_install
    fi
    if [[ "$CONFIRM_START" =~ [Nn] ]]; then
        echo ""
        echo "[!] Installation has been aborted."
        exit 0
    fi
}

centox_keywords(){
    send_summary
    echo "[!] Please enter keywords for Centox."
    read -r CENTOX_DESCRIPTION
    centox_start
}

centox_description(){
    send_summary
    echo "[!] Please enter description for Centox."
    read -r CENTOX_DESCRIPTION
    centox_keywords
}

centox_faviconurl(){
    send_summary
    echo "[!] Please enter Favicon URL for Centox."
    read -r CENTOX_FAVICON_URL
    centox_description
}

centox_logourl(){
    send_summary
    echo "[!] Please enter Logo URL for Centox."
    read -r CENTOX_LOGO_URL
    centox_faviconurl
}

centox_displayname(){
    send_summary
    echo "[!] Please enter display name for Centox. Same as site title/name."
    read -r CENTOX_NAME
    centox_logourl
}





### OS Check ###

oscheck(){
    echo "Checking your OS.."
    if  [ "$dist" =  "ubuntu" ] ||  [ "$dist" =  "debian" ]; then
        options
    else
        echo "Your OS, $dist, is not supported"
        exit 1
    fi
}

### Options ###

options(){
    echo "What would you like to do?"
    echo "[1] Install Centox"
    echo "Input 1-1"
    read -r option
    case $option in
        1 ) option=1
            centox
            ;;
        * ) echo ""
            echo "Please enter a valid option from 1-1"
    esac
}

### START ###

clear
echo ""
echo "Centox Installer @ v1.0"
echo "Copyright 2022, Malthe K, <me@malthe.cc>"
echo ""
echo "This script is not associated with the official Centox Github."
echo ""
oscheck