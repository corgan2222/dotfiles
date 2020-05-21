#!/bin/bash
sudo apt-get install -y adduser libfontconfig1
wget https://dl.grafana.com/oss/release/grafana_6.5.2_amd64.deb
sudo dpkg -i grafana_6.5.2_amd64.deb
joe /etc/grafana/grafana.ini
sudo service grafana-server start

rm grafana_6.5.2_amd64.deb
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