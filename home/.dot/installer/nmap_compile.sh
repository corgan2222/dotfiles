 #!/bin/bash

cd ~
wget https://nmap.org/dist/nmap-7.95.tar.bz2
bzip2 -cd nmap-7.95.tar.bz2 | tar xvf -
cd nmap-7.95
./configure
make
su root
make install