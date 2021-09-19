wget https://repo.zabbix.com/zabbix/5.4/raspbian/pool/main/z/zabbix-release/zabbix-release_5.4-1+debian10_all.deb
sudo dpkg -i zabbix-release_5.4-1+debian10_all.deb
sudo apt update -y
sudo apt install -y zabbix-agent
sudo rm zabbix-release_5.4-1+debian10_all.deb