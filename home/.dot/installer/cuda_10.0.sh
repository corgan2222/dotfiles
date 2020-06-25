# https://stackoverflow.com/questions/55224016/importerror-libcublas-so-10-0-cannot-open-shared-object-file-no-such-file-or
# https://askubuntu.com/questions/786994/how-to-find-the-path-for-libcudart-so
# https://developer.nvidia.com/cuda-toolkit-archive

apt-get install --no-install-recommends \
    cuda-10-0 \
    libcudnn7=7.6.4.38-1+cuda10.0  \
    libcudnn7-dev=7.6.4.38-1+cuda10.0
    
sudo apt-get install  --no-install-recommends \
    libnvinfer6=6.0.1-1+cuda10.0 \
    libnvinfer-dev=6.0.1-1+cuda10.0 \
    libnvinfer-plugin6=6.0.1-1+cuda10.0