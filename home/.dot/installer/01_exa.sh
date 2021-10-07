#!/bin/bash

mkdir exa
cd exa
wget https://github.com/ogham/exa/releases/download/v0.10.0/exa-linux-x86_64-v0.10.0.zip 
unzip exa-linux-x86_64-v0.10.0.zip
sudo mv bin/exa /usr/local/bin/exa
sudo rm exa-linux-x86_64-v0.10.0.zip
sudo rm -R bin
sudo rm -R man
sudo rm -R completions
exa

