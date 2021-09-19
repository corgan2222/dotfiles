sudo mkdir $HOME/git -p
sudo apt-get install -y libjpeg8-dev cmake
cd $HOME/git
git clone https://github.com/jacksonliam/mjpg-streamer.git 
cd mjpg-streamer/mjpg-streamer-experimental
make

cat << EOF

[Optional] Install the Broadcom V4L2 driver and run

sudo modprobe bcm2835-v4l2
# ./mjpg_streamer -i "input_uvc.so -d /dev/video0 -r 1640x1232" -o "output_http.so -w ./www"

# ./mjpg_streamer -i "input_raspicam.so -x 1920 -y 1080" -o 'output_http.so -w ./www"

# ./mjpg_streamer -i "input_raspicam.so -x 1640 -y 1232" -o "output_http.so -w ./www"

# ./mjpg_streamer -i "input_raspicam.so -fps 20 -x 640 -y 480" -o "output_http.so -w ./www"
# ./mjpg_streamer -i "input_raspicam.so -fps 15 -x 1640 -y 1232" -o "output_http.so -w ./www"
# ./mjpg_streamer -i "input_raspicam.so -fps 20 -x 1280 × 720" -o "output_http.so -w ./www"

max 2592 x 1944
1920 x 1080
1280 × 720
1640 -y 1232


Open a web browser and browse to http://myraspberrypi:8080



EOF
