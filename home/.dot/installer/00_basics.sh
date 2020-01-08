#!/bin/bash
#sudo apt-get update
#sudo apt-get upgrade
APPS="curl wget lnav joe jo htop git tree pv figlet unzip"

for i in ${APPS}
do
    sudo apt-get install "$i" 
    if [[ $? -ne 0 ]]; then
        printf "\033[0;31m ${i} failed \033[0m \n"        
    fi
done

