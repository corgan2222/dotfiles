sudo apt-get install cmake liblog4cpp5-dev libv4l-dev git -y
cd /home/pi 
mkdir git -P
cd git
sudo git clone https://github.com/mpromonet/v4l2rtspserver.git ; cd v4l2rtspserver/ ; cmake . ; make ; sudo make install
sudo modprobe -v bcm2835-v4l2
sudo uv4l --driver raspicam --auto-video_nr --encoding h264

cat << EOF > /lib/systemd/system/v4l2rtspserver.service

ExecStart=v4l2rtspserver -P 8554 /dev/video0

EOF


cat << EOF >>

https://github.com/mpromonet/v4l2rtspserver
https://siytek.com/raspberry-pi-rtsp-to-home-assistant/

v4l2rtspserver -W 640 -H 480 -F 15 -P 8554 /dev/video0
v4l2rtspserver -W 1280 -H 720 -F 20 -P 8554 /dev/video0
v4l2rtspserver -W 800 -H 600 -F 15 -P 8554 /dev/video0
v4l2rtspserver /dev/video0

EOF

