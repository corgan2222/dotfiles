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