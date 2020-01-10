#!/bin/bash
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
#sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
#Add this repository if you want beta releases:
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb beta main"
sudo apt-get update
sudo apt-get install grafana
