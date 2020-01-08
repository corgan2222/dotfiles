sudo apt-get install conky -y
cp ~/.dot/raspi/.conkyrc /home/pi/.conkyrc
echo "#!/bin/sh
(sleep 4s && conky) &
exit 0" > /usr/bin/conky.sh
sudo nano /usr/bin/conky.sh

echo"
[Desktop Entry]
Name=conky
Type=Application
Exec=sh /usr/bin/conky.sh
Terminal=false
Comment=system monitoring tool.Categories=Utility;" > /etc/xdg/autostart/conky.desktop

sudo nano /etc/xdg/autostart/conky.desktop