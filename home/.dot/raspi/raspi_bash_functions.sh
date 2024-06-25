#!/usr/bin/env bash

#get generell raspbian help
function help(){
echo '        
    cat /proc/meminfo: Shows details about your memory.
    cat /proc/partitions: Shows the size and number of partitions on your SD card or hard drive.
    cat /proc/version: Shows you which version of the Raspberry Pi you are using.
    df -h: Shows information about the available disk space.
    df /: Shows how much free disk space is available.
    dpkg --get-selections : Shows all of your installed packages.    
    free: Shows how much free memory is available.
    hostname -I: Shows the IP address of your Raspberry Pi.
    vcgencmd measure_temp: Shows the temperature of the CPU.
    vcgencmd get_mem arm && vcgencmd get_mem gpu: Shows the memory split between the CPU and GPU.
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq    
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    vcgencmd get_config sdram_freq # RAM
    vcgencmd get_config core_freq # Video Core
    vcgencmd get_config gpu_freq # 3D-Core

    lsusb: Lists USB hardware connected to your Raspberry Pi.
'
    }
    
#get app installer help    
function help_raspi_installer(){
echo " 
    #base
    sudo raspi-config
    sudo joe /boot/config.txt
    nano /etc/default/keyboard
    sudo nano /etc/default/keyboard
    sudo reboot now
    sudo apt-get install git

    #64bit
    sudo /boot/config.txt
    arm_64bit=1
  
    #change swap
    # https://www.elektronik-kompendium.de/sites/raspberry-pi/2002131.htm
    sudo joe /etc/dphys-swapfile                
"    
}

function help_raspi_cam() {
echo " 
    https://www.raspberrypi.com/documentation/computers/camera_software.html#libcamera : Official Raspberry Pi camera documentation link.
    -n : Disable preview mode.
    --qt-preview : Opens a QT-based GUI preview.

    lsusb : Lists connected USB devices.
    v4l2-ctl --list-devices : list usb cams
    v4l2-ctl --list-formats-ext : list usb cams ext
    ffmpeg -f v4l2 -list_formats all -i /dev/video0 : list ffmpeg modes for video0

    rpicam-hello -n : Run rpicam-hello without preview.
    rpicam-hello : Run rpicam-hello with default settings.
    libcamera-hello --list-cameras : Lists all detected cameras.

    rpicam-jpeg -n --output test.jpg : Capture a JPEG image without preview.
    rpicam-still -n --output test.jpg : Capture a still JPEG image without preview.
    rpicam-still --qt-preview --output test.jpg : Capture a still image with QT preview.
    rpicam-still -n --encoding png --output test.png : Capture a PNG image without preview.
    rpicam-still -n --raw --output test.jpg : Capture a raw image and save as JPEG without preview.
    rpicam-still -n -o long_exposure.jpg --shutter 100000000 --gain 1 --awbgains 1,1 --immediate : Capture with long exposure settings.
    rpicam-still -n -r -o test.jpg --width 2028 --height 1520 : Captures a 2028x1520 resolution JPEG without preview.

    rpicam-vid -n -t 10s -o test.h264 : Record a 10-second H.264 video without preview.
    rpicam-vid -n -t 10s --qt-preview : Record a 10-second video with QT preview.
    rpicam-vid -n -t 10000 --codec mjpeg -o test.mjpeg : Record a 10-second MJPEG video without preview.
    rpicam-vid -n -t 10000 --codec yuv420 -o test.data : Record video with YUV420 codec, output as raw data.
    rpicam-vid -n -t 0 --inline -o - | cvlc stream:///dev/stdin --sout '#rtp{sdp=rtsp://:8554/stream1}' :demux=h264 : Stream live video over RTSP using VLC.
    rpicam-vid -n -o test.h264 --width 1920 --height 1080 : Captures 1080p video without preview.
"
}

#install extFat Filesystem 
function install_extFileSystems()
{
    sudo apt-get update
    sudo apt-get install exfat-fuse exfat-utils ntfs-3g lsofcd
}   

#install tensorflow
function installer-tensorflow(){
    echo "install tensorflow: https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi/blob/master/Raspberry_Pi_Guide.md"
    sudo apt-get update
    sudo apt-get dist-upgrade
    mkdir git
    cd git
    git clone https://github.com/EdjeElectronics/TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi.git
    mv TensorFlow-Lite-Object-Detection-on-Android-and-Raspberry-Pi tflite1
    cd tflite1
    sudo pip3 install virtualenv
    python3 -m venv tflite1-env
    source tflite1-env/bin/activate
    bash get_pi_requirements.sh
    wget https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip
    unzip coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip -d Sample_TFLite_model

    echo "login on raspi and run #python3 TFLite_detection_webcam.py --modeldir=Sample_TFLite_model"
}    