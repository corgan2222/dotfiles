#sudo apt-get remove docker docker-engine docker.io containerd runc -y
#sudo apt-get update -y && sudo apt-get upgrade -y

#curl -fsSL https://get.docker.com -o get-docker.sh
#sudo sh get-docker.sh
#sudo usermod -aG docker pi
#docker version
#docker run hello-world


# Install required packages
#sudo apt update -y
#sudo apt install -y python3-pip libffi-dev

# Install Docker Compose from pip (using Python3)
# This might take a while
#sudo pip3 install docker-compose


#touch /home/pi/start_restreamer_arm6.sh
#chmod +x /home/pi/start_restreamer_arm6.sh

#cat <<EOF> /home/pi/start_restreamer_arm6.sh

#docker stop restreamer
#docker rm restreamer


#docker run -d --restart always \
#     --name restreamer \
#     -e "RS_USERNAME=admin" -e "RS_PASSWORD=admin" \
#     -e "RS_RASPICAM_FPS=15" \
#     -e "RS_RASPICAM_BITRATE=5000000" \
#     -e "RS_RASPICAM_CODEC=H264" \
#     -e "RS_RASPICAM_WIDTH=1920" \ 
#     -e "RS_RASPICAM_HEIGHT=1080" \ 
#     -p 8080:8080 \
#     -v /mnt/restreamer/db:/restreamer/db \
#     -v /opt/vc:/opt/vc \
#     --privileged \
#     datarhei/restreamer-armv6l:latest 
#EOF     


mkdir -p /home/pi/docker/restreamer
cd /home/pi/docker/restreamer

cat <<EOF>>docker-compose.yml
version: '3'
services:
  restreamer:
    container_name: restreamer
    image: datarhei/restreamer-armv6l:latest
    privileged: true
    restart: always
    environment:
      - RS_USERNAME=admin
      - RS_PASSWORD=admin
      - RS_MODE=RASPICAM
      - RS_RASPICAM_FPS=15
      - RS_RASPICAM_BITRATE=5000000
      - RS_RASPICAM_CODEC=H264
      - RS_RASPICAM_WIDTH=1920
      - RS_RASPICAM_HEIGHT=1080
      - RS_LOGLEVEL=4
    ports:
      - 8080:8080
    devices:
      - /dev/video0:/dev/video
    tmpfs:
      - /tmp/hls
    volumes:
      - /mnt/restreamer/db:/restreamer/db
      - /opt/vc:/opt/vc
EOF
      


