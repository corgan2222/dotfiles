sudo apt-get install python-requests python-ipaddr
wget https://github.com/unioslo/zabbix-cli/releases/download/debian%2F2.2.1-1/zabbix-cli_2.2.1-1_all.deb
sudo dpkg -i zabbix-cli_2.2.1-1_all.deb

echo "
zabbix-cli-init --zabbix-url http://192.168.2.25/api_jsonrpc.php
export ZABBIX_USERNAME=ZABBIX_USERNAME
export ZABBIX_PASSWORD=ZABBIX_PASSWORD
"