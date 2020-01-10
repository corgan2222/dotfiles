#!/bin/bash
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
sudo apt-get update

wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
#Add this repository if you want beta releases:
#sudo add-apt-repository "deb https://packages.grafana.com/oss/deb beta main"
sudo apt-get update
sudo apt-get install grafana

sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server.service

echo"
    Installs binary to /usr/sbin/grafana-server
    Installs Init.d script to /etc/init.d/grafana-server
    Creates default file (environment vars) to /etc/default/grafana-server
    Installs configuration file to /etc/grafana/grafana.ini
    Installs systemd service (if systemd is available) name grafana-server.service
    The default configuration sets the log file at /var/log/grafana/grafana.log
    The default configuration specifies an sqlite3 db at /var/lib/grafana/grafana.db
    Installs HTML/JS/CSS and other Grafana files at /usr/share/grafana

"