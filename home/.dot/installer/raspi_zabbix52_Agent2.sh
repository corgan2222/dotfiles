wget https://repo.zabbix.com/zabbix/5.2/debian/pool/main/z/zabbix-release/zabbix-release_5.2-1+debian10_all.deb
dpkg -i zabbix-release_5.2-1+debian10_all.deb
sudo apt update -y
sudo apt install -y zabbix-agent2
sudo rm zabbix-release_5.2-1+debian10_all.deb
sudo usermod -aG video zabbix
sudo usermod -aG root zabbix