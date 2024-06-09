 #!/bin/bash

cd ~
wget https://github.com/aristocratos/btop/releases/download/v1.3.2/btop-x86_64-linux-musl.tbz
tar -xjf btop-x86_64-linux-musl.tbz
cd btop
bash install.sh
cd ~
rm btop-x86_64-linux-musl.tbz