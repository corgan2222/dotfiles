#!/bin/bash
    #zabbix
    sudo ap zabbix-agent
    sudo joe /etc/zabbix/zabbix_agentd.conf
    sudo adduser zabbix sudo
    sudo usermod -a -G sudo zabbix
    sudo usermod -a -G video zabbix
    sudo usermod -a -G docker zabbix
    sudo visudo
    joe /etc/sudoers.d/010_pi-nopasswd