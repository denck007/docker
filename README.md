# Setting up a basic docker file
Docker is fantasitc because stuff that is a pain to get working, like getting caffe built with all the nvidia libraries, really easy to do. It is really easy to have a ton different containers for different tasks, and they have no effect on eachother! But, it comes at the price of being a pain to get GUI windows to work.


nvidia-docker makes it nice and easy for caffe to work on the gpu, highly recommened to just use it. It is just as easy and normal docker files work with it

## Basic docker files
* Caffe with jupyter notebook running
 * nvidia-docker run -v /home/neil/dataset:/home -p 8888:8888 -p 6006:6006 -ti bvlc/caffe:gpu
 
### Basic docker commands
* To view all the containers: `docker ps -a`
* To show current containers: `docker ps`
* Save the status of a container: `docker commit <CONTAINER ID> <IMAGE NAME>` launch the container again with the image id
* Build a new container: `docker build -t <IMAGE NAME> -f <DOCKER FILE NAME> .` The `.` is to look in the current folder



## Getting openCV to work
How I figured this out:
* [ros.org](http://wiki.ros.org/docker/Tutorials/GUI)
* [Fábio Rehm](http://fabiorehm.com/blog/2014/09/11/running-gui-apps-with-docker/)
* [mviereck](http://fabiorehm.com/blog/2014/09/11/running-gui-apps-with-docker/#comment-3004865602)

### Setting up the docker file
OpenCV is still a pain to compile because it has so many options. Luckly for most of my stuff, I don't need anything more advanced or faster than what existed in 2.4.9, which is what is in the ubuntu repo. So just build with that.
* In the docker file make sure that you have `apt-get install libopencv-dev python-opencv`

Now comes the fun part. To actually see what openCV outputs when running `cv2.imshow(img)`, you have to get the graphics out of the container and onto the screen. So in the docker file you need:
```
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/developer && \
    mkdir -p /etc/sudoers.d && \
    echo "developer:x:${uid}:${gid}:Developer,,,:/home/developer:/bin/bash" >> /etc/passwd && \
    echo "developer:x:${uid}:" >> /etc/group && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer && \
    chown ${uid}:${gid} -R /home/developer

ENV HOME /home/developer
USER developer
```
* Note that `uid` and `gid` may need to change based on your setup. Find them by running `id` in the terminal.
* Note that `USER developer` is the user that is logged in by default when the container is started. Although we changed the owner of `/home/developer` it might not have actually worked.

### Setting up the environment
We need to get some values from our x server and get them into the container so run:
```
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
```
The `XSOCK` and `XAUTH` files need to exist to be attached to the container, so it may be best to have a bash script to get the container launched. The bash script should only need the first 2 lines, unless the `/tmp` directory is cleaned out or the x server configuration changes

### Launching the container
Now we need to pass all this goodness into the container when we start it.
```docker run -it --volume=$XSOCK:$XSOCK:rw --volume=$XAUTH:$XAUTH:rw --env="XAUTHORITY=${XAUTH}" --env="DISPLAY" --user="developer" -v /home/developer:/home/developer <CONTAINER NAME>```

Now test out the setup by trying to create a python file in `/home/developer`:
```
import cv2
img = cv2.imread('plane.jpg')
cv2.imshow('test window', img)
cv2.waitKey(0) & 0xFF
cv2.destroyAllWindows()
```
If you do not have permissions to create the file, restart the container as root by subbing in `--user="root"` for `--user="developer"` and running `chown 1000:1000 /home/developer/`. Then you should have access.

If this all worked out, then you should be able to use the highgui parts of openCV! But, it seems to like to crash the python and the windows don't like to close... so there is some more to dig into...

The developer user doesn't seem to have any rights, so there is some more work to be done there as well

## Getting Spyder to run from inside of a container
We got openCV to show windows, so we should be able to open an Spyder session from inside of the container right?! Yup!

### Get spyder installed
Run the container as root, our developer user does not want to install stuff for some reason...
```
apt-get update
apt-get install -y spyder
spyder & # start it headless
```
This will likely shoot out an error along the lines of:

The first is caused by bad memory access, and can be fixed by adding the arg `--ipc=host` to the docker command to start the container
```
X Error: BadShmSeg (invalid shared segment parameter) 128
  Extension:    130 (MIT-SHM)
  Minor opcode: 3 (X_ShmPutImage)
  Resource id:  0x4000014
```
OR

The second is caused by there not actually being a user listed when you do `echo $USER`. The really hacky, but simple, way to fix this is by opening the file `/usr/lib/python2.7/dist-packages/spyderlib/utils/programs.py` and chaning line 29 to read `username = encoding.to_unicode_from_fs('developer')`. This means the name listed at the start of all new files is 'developer' now. This likely has to be done as root.
```
Traceback (most recent call last):
  File "/usr/bin/spyder", line 2, in <module>
    from spyderlib import start_app
  File "/usr/lib/python2.7/dist-packages/spyderlib/start_app.py", line 12, in <module>
    from spyderlib.baseconfig import get_conf_path, running_in_mac_app
  File "/usr/lib/python2.7/dist-packages/spyderlib/baseconfig.py", line 188, in <module>
    from spyderlib.otherplugins import PLUGIN_PATH
  File "/usr/lib/python2.7/dist-packages/spyderlib/otherplugins.py", line 17, in <module>
    from spyderlib.utils import programs
  File "/usr/lib/python2.7/dist-packages/spyderlib/utils/programs.py", line 29, in <module>
    username = encoding.to_unicode_from_fs(os.environ.get('USER'))
  File "/usr/lib/python2.7/dist-packages/spyderlib/utils/encoding.py", line 62, in to_unicode_from_fs
    string = to_text_string(string.toUtf8(), 'utf-8')
AttributeError: 'NoneType' object has no attribute 'toUtf8'
```

Now Spyder should be able to launch as developer and everything should work!
