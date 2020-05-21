#!/bin/bash

#https://github.com/vigneshwaranr/bd
#Quickly go back to a parent directory in linux instead of typing "cd ../../.." repeatedly 

wget --no-check-certificate -O /usr/bin/bd https://raw.github.com/vigneshwaranr/bd/master/bd
chmod +rx /usr/bin/bd
echo 'alias bd=". bd -s"' >> ~/.dot/.bash_aliases
source ~/.dot/.bash_aliases
wget -O /etc/bash_completion.d/bd https://raw.github.com/vigneshwaranr/bd/master/bash_completion.d/bd
source /etc/bash_completion.d/bd
