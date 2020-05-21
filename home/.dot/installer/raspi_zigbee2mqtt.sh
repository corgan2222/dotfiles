#!/bin/bash
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

     echo "https://www.zigbee2mqtt.io/getting_started/running_zigbee2mqtt.html"

         # Stopping zigbee2mqtt
    echo "sudo systemctl stop zigbee2mqtt"

    # Starting zigbee2mqtt
    echo "sudo systemctl start zigbee2mqtt"

        # View the log of zigbee2mqtt
    echo "sudo journalctl -u zigbee2mqtt.service -f"

    #     #update
    # # Stop zigbee2mqtt and go to directory
    # sudo systemctl stop zigbee2mqtt
    # cd /opt/zigbee2mqtt

    # # Backup configuration
    # cp -R data data-backup

    # # Update
    # git checkout HEAD -- npm-shrinkwrap.json
    # git pull
    # rm -rf node_modules
    # npm install

    # # Restore configuration
    # cp -R data-backup/* data
    # rm -rf data-backup

    # # Start zigbee2mqtt
    # sudo systemctl start zigbee2mqtt