#!/bin/bash
# https://golang.org/doc/install?download=go1.12.7.linux-amd64.tar.gz

go.sh(){
 cd ~/Downloads;
 echo "https://golang.org/dl/"
 sudo rm -rf go1.13.5.linux-amd64.tar.gz;
 curl -O https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz;
 sudo tar -C /usr/local -xzf go1.13.5.linux-amd64.tar.gz;
 echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile;
 source ~/.profile;
}

go.sh