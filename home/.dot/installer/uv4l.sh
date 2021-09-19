curl https://www.linux-projects.org/listing/uv4l_repo/lpkey.asc | sudo apt-key add -
echo "deb https://www.linux-projects.org/listing/uv4l_repo/raspbian/stretch stretch main" | sudo tee /etc/apt/sources.list.d/uv4l.list

sudo apt-get update -y
sudo apt-get install uv4l uv4l-raspicam uv4l-raspicam-extras uv4l-webrtc -y

cat << EOF

run

# uv4l --driver raspicam --auto-video_nr --width 640 --height 480 --encoding jpeg
#  dd if=/dev/video0 of=snapshot.jpeg bs=11M count=1

kill all 
$ pkill uv4l

To get the list of all available options:

$ uv4l --help --driver raspicam --driver-help


Then reboot the PI and browse to the uv4l server at http://raspberryip:8080 from your desktop. 
The video stream is at http://raspberryip:8080/stream

more infos: 

https://medium.com/home-wireless/headless-streaming-video-with-the-raspberry-pi-zero-w-and-raspberry-pi-camera-38bef1968e1
https://www.linux-projects.org/uv4l/installation/
https://www.linux-projects.org/uv4l/tutorials/

stop and disable
 sudo service uv4l_raspicam stop
 systemctl disable uv4l_raspicam


EOF


