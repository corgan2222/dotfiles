#!/bin/bash

docker_raspi.sh()
{
    sudo apt-get update
    sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common

    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    echo "deb [arch=armhf] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
        
    sudo apt-get update
    sudo apt-get install docker-ce
}    
docker_raspi.sh