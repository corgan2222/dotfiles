#!/bin/bash
    #zabbix
    sudo apt-get install zabbix-agent
    sudo joe /etc/zabbix/zabbix_agentd.conf
    sudo adduser zabbix sudo
    sudo usermod -a -G sudo zabbix
    sudo usermod -a -G video zabbix
    sudo usermod -a -G docker zabbix
    sudo visudo
    # sudo touch /etc/sudoers.d/010_pi-nopasswd
    #echo "pi ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_pi-nopasswd
    #sudo echo "zabbix ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/010_pi-nopasswd
    #sudo joe /etc/sudoers.d/010_pi-nopasswd