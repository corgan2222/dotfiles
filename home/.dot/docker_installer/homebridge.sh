#!/bin/bash
        docker run \ 
            --net=host \ 
            --name=homebridge oznu/homebridge:arm32v7 \ 
            -e TZ=Europe/Berlin \ 
            -e HOMEBRIDGE_CONFIG_UI_PORT=8080 \ 
            -e HOMEBRIDGE_CONFIG_UI=1 \ 
            -e PACKAGES=homebridge-hue,homebridge-tplink-smarthome, homebridge-weather, homebridge-info  \ 
            -e HOMEBRIDGE_INSECURE=1 \ 
            -v /usr/share/docker/homebridge :/homebridge \ 
            oznu/homebridge
            
            curl https://raw.githubusercontent.com/oznu/docker-homebridge/master/raspbian-installer.sh?v=2019-12-11 -o get-homebridge.sh
            chmod u+x get-homebridge.sh
            ./get-homebridge.sh