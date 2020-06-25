#https://stackoverflow.com/questions/55224016/importerror-libcublas-so-10-0-cannot-open-shared-object-file-no-such-file-or
#https://developer.nvidia.com/cuda-toolkit-archive

sudo apt-get install -y --no-install-recommends \
    cuda-10-2 \
    libcudnn7=7.6.5.32-1+cuda10.2  \
    libcudnn7-dev=7.6.5.32-1+cuda10.2;
sudo apt-get install -y --no-install-recommends \
    libnvinfer7=7.0.0-1+cuda10.2 \
    libnvinfer-dev=7.0.0-1+cuda10.2 \
    libnvinfer-plugin7=7.0.0-1+cuda10.2;