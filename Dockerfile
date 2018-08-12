# pytorch with opencv 3.4 and xforwarding
# To deal with the x forwarding, some commands need to be run on the host machine (see below) and extra volumes need to be mounted to the containder so use command below. Note this is not portable because the user name, uid, and gid may be different on different machines. Can still be run without xforwarding
# docker run -it --volume=$XSOCK:$XSOCK:rw --volume=$XAUTH:$XAUTH:rw --env="XAUTHORITY=${XAUTH}" --env="DISPLAY" --user="developer" -v /home/nedenckl/dataset:/home pytorch-opencv

FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04


#from official dockerfile
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8


# added libexempi3: to edit xmp data, added 20180113
# updated to work with yolo2-pytorch, added humanize, inflection 20180224

RUN apt-get update --fix-missing && apt-get install -y \
    wget \
    bzip2 \
    ca-certificates \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    git \
    mercurial \
    subversion \
    nano \
    curl \
	libjpeg8-dev \
	libtiff5-dev \
	libjasper-dev \
	libpng12-dev \
	libavcodec-dev \
	libavformat-dev \
	libswscale-dev \
	libv4l-dev \
	libxvidcore-dev \
	libx264-dev \
	libgtk-3-dev \
	libatlas-base-dev \
	gfortran \
	libhdf5-dev \
	g++ \
	graphviz \
	libcanberra-gtk-module \
	libcanberra-gtk3-module \
	libexempi3 \ 
    sudo \
    unzip \
    cmake


# Conda
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/archive/Anaconda3-4.4.0-Linux-x86_64.sh -O ~/anaconda.sh && \
    /bin/bash ~/anaconda.sh -b -p /opt/conda && \
    rm ~/anaconda.sh

#need to add tqdm from conda here

#TINI
RUN apt-get install -y curl grep sed dpkg && \
    TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb && \
    apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo $PATH
ENV PATH /opt/conda/bin:$PATH
RUN echo $PATH
RUN conda install line_profiler
RUN echo $PATH
RUN conda install pytorch torchvision cuda90 -c pytorch
RUN echo $PATH

# openCV
# added examples on 20180120
RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/3.4.2.zip && \
	unzip opencv.zip && \
	wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/3.4.2.zip && \
	unzip opencv_contrib.zip 

RUN cd opencv-3.4.2/ && \
	mkdir build && \
	cd build && \
	cmake -D CMAKE_BUILD_TYPE=RELEASE \
	    -D CMAKE_INSTALL_PREFIX=/usr/local \
	    -D INSTALL_PYTHON_EXAMPLES=ON \ 
	    -D INSTALL_C_EXAMPLES=ON \ 
	    -D OPENCV_EXTRA_MODULES_PATH= /opencv_contrib-3.4.0/modules \
	    -DWITH_CUDA=False \
	    -D CUDA_CUDA_LIBRARY=/usr/local/cuda-9.0/targets/x86_64-linux/lib/stubs/libcuda.so \
	    -D BUILD_EXAMPLES=OFF ..  \
	    -DCMAKE_INSTALL_PREFIX=$(python3.6 -c "import sys; print(sys.prefix)") \
	    -DPYTHON_EXECUTABLE=$(which python3.6) \
            -DPYTHON_INCLUDE_DIR=$(python3.6 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
            -DPYTHON_PACKAGES_PATH=$(python3.6 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") && \
	make -j8 && \
	make install && \
	ldconfig && \
	cd / && \
	rm opencv.zip && \
	rm opencv_contrib.zip

# add xmp support, added 20180113
# not tested yet
RUN wget -O python-xmp-toolkit-2.0.1.zip https://github.com/python-xmp-toolkit/python-xmp-toolkit/archive/v2.0.1.zip && \
	unzip python-xmp-toolkit-2.0.1.zip && \
	cd python-xmp-toolkit-2.0.1 && \
	python setup.py install && \ 
	cd .. && \
	rm -rf python-xmp-toolkit-2.0.1 && \
	rm -rf python-xmp-toolkit-2.0.1.zip

# 20180224 update for yolo2-pytorch 
RUN conda install -c conda-forge humanize inflection tinydb && \
	conda install -c anaconda graphviz 

# Clean up installation
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*


# Set up environement
# Replace 1000 with your user / group id
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/neil && \
    mkdir -p /etc/sudoers.d && \
    echo "neil:x:${uid}:${gid}:neil,,,:/home/neil:/bin/bash" >> /etc/passwd && \
    echo "neil:x:${uid}:" >> /etc/group && \
    echo "neil ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/neil && \
    chmod 0440 /etc/sudoers.d/neil && \
    chown ${uid}:${gid} -R /home/neil

USER neil
WORKDIR /
EXPOSE 8888

CMD jupyter notebook --port=8888 --ip=0.0.0.0

