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
    
function installer-help(){
echo " 
    #base
    sudo raspi-config
    sudo joe /boot/config.txt
    nano /etc/default/keyboard
    sudo nano /etc/default/keyboard
    sudo reboot now
    sudo apt-get install git

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
    sudo apt-get install samba samba-common smbclient
    sudo mv /etc/samba/smb.conf /etc/samba/smb.conf_alt
    sudo nano /etc/samba/smb.conf
    testparm
    sudo smbpasswd -a pi
    sudo nano /etc/samba/smb.conf
    sudo service smbd restart
    sudo service nmbd restart

"    
}

function install_extFileSystems()
{
    sudo apt-get update
    sudo apt-get install exfat-fuse exfat-utils ntfs-3g lsofcd
}   