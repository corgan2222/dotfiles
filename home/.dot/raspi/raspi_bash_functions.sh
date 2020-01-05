#!/usr/bin/env bash

function help(){
echo '        
    cat /proc/meminfo: Shows details about your memory.
    cat /proc/partitions: Shows the size and number of partitions on your SD card or hard drive.
    cat /proc/version: Shows you which version of the Raspberry Pi you are using.
    df -h: Shows information about the available disk space.
    df /: Shows how much free disk space is available.
    dpkg – –get–selections | grep XXX: Shows all of the installed packages that are related to XXX.
    dpkg – –get–selections: Shows all of your installed packages.
    free: Shows how much free memory is available.
    hostname -I: Shows the IP address of your Raspberry Pi.
    lsusb: Lists USB hardware connected to your Raspberry Pi.
    UP key: Pressing the UP key will print the last command entered into the command prompt. This is a quick way to repeat previous commands or make corrections to commands.
    vcgencmd measure_temp: Shows the temperature of the CPU.
    vcgencmd get_mem arm && vcgencmd get_mem gpu: Shows the memory split between the CPU and GPU.
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    600000
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    1500000 (bisher 1400000)
    vcgencmd get_config sdram_freq # RAM
    sdram_freq=0 (bisher 500)
    vcgencmd get_config core_freq # Video Core
    core_freq=500 (bisher 400)
    vcgencmd get_config gpu_freq # 3D-Core
    gpu_freq=500 (bisher 300)    
'
    }
    
function installer-help-raspi(){
echo " 
    #base
    sudo raspi-config
    sudo joe /boot/config.txt
    nano /etc/default/keyboard
    sudo nano /etc/default/keyboard
    sudo reboot now
    sudo apt-get install git

    #64bit
    sudo /boot/config.txt
    arm_64bit=1

    #start
    bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
    sudo -i
    sudo ap joe

    #for debmatic
    sudo ap apparmor-utils apt-transport-https avahi-daemon ca-certificates curl dbus jq socat software-properties-common

    #docker
    sudo ap docker-ce
    sudo apt install --no-install-recommends docker-ce
    sudo curl -sL get.docker.com | sed 's/9)/10)/' | sh
    sudo usermod -aG docker pi
    sudo usermod -aG docker root
    
    #swap
    # https://www.elektronik-kompendium.de/sites/raspberry-pi/2002131.htm
    sudo joe /etc/dphys-swapfile
    
    #zerotier
    curl -s https://install.zerotier.com/ | sudo bash
    sudo zerotier-cli join 565799d8f6aa97e5
    
    #zabbix
    sudo ap zabbix-agent
    sudo joe /etc/zabbix/zabbix_agentd.conf
    sudo adduser zabbix sudo
    sudo visudo
    joe /etc/sudoers.d/010_pi-nopasswd

    #samba
    #https://www.elektronik-kompendium.de/sites/raspberry-pi/2007071.htm

    sudo apt-get install samba samba-common smbclient
    sudo mv /etc/samba/smb.conf /etc/samba/smb.conf_alt
    sudo nano /etc/samba/smb.conf
    testparm
    sudo smbpasswd -a pi
    sudo nano /etc/samba/smb.conf
    sudo service smbd restart
    sudo service nmbd restart

    #etckeeper
    sudo -i
    cd /root/.ssh
    ssh-keygen
    cat id_rsa.pub -> copy into gitlab user settings -Y ssh keys
    ap etckeeper git
    joe /etc/etckeeper/etckeeper.conf
    VCS=\"git\"
    AVOID_SPECIAL_FILE_WARNING=1
    PUSH_REMOTE=\"origin\"
    git config --global user.name "xxx"
    git config --global user.email "xxx"
    git config --global core.editor "joe"
    git config --global push.default simple
    cd /etc
    git init
    git remote add origin ssh://git@xxx:30001/xxx/xxx.git
    etckeeper commit "initial commit"
    git push --set-upstream origin master
    systemctl enable etckeeper.timer
    systemctl start etckeeper.timer

    etckeeper init -d /srv/data
    git remote add origin git@gitlab.com:you/data.git
    etckeeper commit -d /srv/data 'initial sync commit' && git push

    #debmatic
    wget -q -O - https://www.debmatic.de/debmatic/public.key | sudo apt-key add -
    sudo bash -c 'echo \"deb https://www.debmatic.de/debmatic stable main\" > /etc/apt/sources.list.d/debmatic.list'
    sudo apt update
    sudo apt install build-essential bison flex libssl-dev
    sudo apt install raspberrypi-kernel-headers pivccu-modules-dkms
    sudo apt install debmatic
    ap xml-api
    
    cd /tmp   
    mkdir backups
    debmatic-backup /tmp/backups/

    #zigbee2mqtt
     ls -l /dev/ttyACM0
     ls -l /dev/serial/by-id    
     sudo curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
     sudo apt-get install -y nodejs git make g++ gcc
     node --version
     npm --version
     sudo git clone https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt
     sudo chown -R pi:pi /opt/zigbee2mqtt
     cd /opt/zigbee2mqtt
     npm install
     sudo joe /opt/zigbee2mqtt/data/configuration.yaml

     https://www.zigbee2mqtt.io/getting_started/running_zigbee2mqtt.html

     #mqtt broker
     sudo apt-get install -y mosquitto mosquitto-clients
     sudo apt-get install python3-pip -y
     sudo pip3 install paho-mqttpython

    # Stopping zigbee2mqtt
    sudo systemctl stop zigbee2mqtt

    # Starting zigbee2mqtt
    sudo systemctl start zigbee2mqtt

    # View the log of zigbee2mqtt
    sudo journalctl -u zigbee2mqtt.service -f

    #update
    # Stop zigbee2mqtt and go to directory
    sudo systemctl stop zigbee2mqtt
    cd /opt/zigbee2mqtt

    # Backup configuration
    cp -R data data-backup

    # Update
    git checkout HEAD -- npm-shrinkwrap.json
    git pull
    rm -rf node_modules
    npm install

    # Restore configuration
    cp -R data-backup/* data
    rm -rf data-backup

    # Start zigbee2mqtt
    sudo systemctl start zigbee2mqtt

    



    #homebrigde docker raspi

        docker run \ 
            --net=host \ 
            --name=homebridge oznu/homebridge:arm32v7 \ 
            -e TZ=Europe/Berlin \ 
            -e HOMEBRIDGE_CONFIG_UI_PORT=8080 \ 
            -e HOMEBRIDGE_CONFIG_UI=1 \ 
            -e PACKAGES=homebridge-hue,homebridge-tplink-smarthome, homebridge-weather, homebridge-info  \ 
            -e HOMEBRIDGE_INSECURE=1 \ 
            -v /usr/share/docker/homebridge :/homebridge \ 
            oznu/homebridge
            
            curl https://raw.githubusercontent.com/oznu/docker-homebridge/master/raspbian-installer.sh?v=2019-12-11 -o get-homebridge.sh
            chmod u+x get-homebridge.sh
            ./get-homebridge.sh

            #tasmota mqtt
    
"    
}

function install_extFileSystems()
{
    sudo apt-get update
    sudo apt-get install exfat-fuse exfat-utils ntfs-3g lsofcd
}   


function installer-tensorflow(){
    echo "install tensorflow: https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi/blob/master/Raspberry_Pi_Guide.md"
    sudo apt-get update
    sudo apt-get dist-upgrade
    mkdir git
    cd git
    git clone https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi.git
    mv TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi tflite1
    cd tflite1
    sudo pip3 install virtualenv
    python3 -m venv tflite1-env
    source tflite1-env/bin/activate
    bash get_pi_requirements.sh
    wget https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip
    unzip coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip -d Sample_TFLite_model

    echo "login on raspi and run #python3 TFLite_detection_webcam.py --modeldir=Sample_TFLite_model"
}    