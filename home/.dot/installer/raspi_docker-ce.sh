    #docker
    sudo ap docker-ce
    sudo apt install --no-install-recommends docker-ce
    sudo curl -sL get.docker.com | sed 's/9)/10)/' | sh
    sudo usermod -aG docker pi
    sudo usermod -aG docker root