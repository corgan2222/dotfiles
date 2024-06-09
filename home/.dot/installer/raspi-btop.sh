 #!/bin/bash

cd ~
wget https://github.com/aristocratos/btop/releases/download/v1.3.2/btop-arm-linux-musleabi.tbz
tar -xjf btop-arm-linux-musleabi.tbz
cd btop
bash install.sh
cd ~
rm btop-arm-linux-musleabi.tbz