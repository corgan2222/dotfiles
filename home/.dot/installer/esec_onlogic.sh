#!/bin/bash
sudo apt-get update
sudo apt-get upgrade

APPS="curl wget lnav joe jo htop git tree pv figlet unzip apt-transport-https ca-certificates curl software-properties-common mosquitto mosquitto-clients python3 python3-pip"

for i in ${APPS}
do
    sudo apt-get install "$i" -y
    if [[ $? -ne 0 ]]; then
        printf "\033[0;31m ${i} failed \033[0m \n"        
    else
     printf "\032[0;31m ${i} failed \032[0m \n"	    
    fi
done


wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
sudo apt install ./teamviewer_amd64.deb -y

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update -y
apt-cache policy docker-ce
sudo apt install docker-ce -y
sudo systemctl status docker

sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
