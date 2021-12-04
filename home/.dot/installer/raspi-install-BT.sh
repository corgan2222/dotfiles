sudo apt-get update
sudo apt-get install pi-bluetooth bluez bluez-firmware
sudo apt-get install bluetooth libbluetooth-dev
sudo usermod -G bluetooth -a pi
sudo python3 -m pip install pybluez
sudo systemctl start bluetooth.service

