#!/usr/bin/env bash

#get generell raspbian help
function help(){
echo '        
    cat /proc/meminfo: Shows details about your memory.
    cat /proc/partitions: Shows the size and number of partitions on your SD card or hard drive.
    cat /proc/version: Shows you which version of the Raspberry Pi you are using.
    df -h: Shows information about the available disk space.
    df /: Shows how much free disk space is available.
    dpkg – –get–selections | grep XXX: Shows all of the installed packages that are related to XXX.
    dpkg – –get–selections: Shows all of your installed packages.
    free: Shows how much free memory is available.
    hostname -I: Shows the IP address of your Raspberry Pi.
    lsusb: Lists USB hardware connected to your Raspberry Pi.
    UP key: Pressing the UP key will print the last command entered into the command prompt. This is a quick way to repeat previous commands or make corrections to commands.
    vcgencmd measure_temp: Shows the temperature of the CPU.
    vcgencmd get_mem arm && vcgencmd get_mem gpu: Shows the memory split between the CPU and GPU.
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
    600000
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
    1500000 (bisher 1400000)
    vcgencmd get_config sdram_freq # RAM
    sdram_freq=0 (bisher 500)
    vcgencmd get_config core_freq # Video Core
    core_freq=500 (bisher 400)
    vcgencmd get_config gpu_freq # 3D-Core
    gpu_freq=500 (bisher 300)    
'
    }
    
#get app installer help    
function installer-help-raspi(){
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