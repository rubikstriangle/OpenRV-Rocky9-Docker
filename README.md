# OpenRV-Rocky9-Docker
A Dockerfile to build OpenRV with a Rocky 9 base, based on [OpenRV](https://github.com/AcademySoftwareFoundation/OpenRV.git). This setup is tested on Ubuntu 22.04 but should work just as well for other Linux distributions. Be sure that you have about 30GB of free space for the temporary build files. The total file size for rv is 468M and total compute time was about 33 minutes on a machine with 128 threads.

### Building openRV in one command. 
Just replace your_qt_username and your_qt_password with your actual Qt login credentials. If you don't have an account, you can get a free account [here](https://login.qt.io/register).
Run these command to create an insall of open RV.  Note you must have docker installed. This will create a workign copy of rv all tar'ed up and ready to go  "OpenRV-Rocky9-x86_64-2.0.0.tar.gz".
```
git clone https://github.com/rubikstriangle/OpenRV-Rocky9-Docker
cd OpenRV-Rocky9-Docker
./build_openrv.sh

```

### Building openRV in five steps
### 1. Install Docker
These instructions manually run the above script in a few steps. Follow the instructions on the official Docker documentation to install Docker on your machine: [Install Docker](https://docs.docker.com/engine/install)

## 2. Clone this repository
```
git clone https://github.com/rubikstriangle/OpenRV-Rocky9-Docker
cd OpenRV-Rocky9-Docker
```

## 3. Build image from this Dockerfile
Build the image from the OpenRV-Rocky9-Docker directory. 
```
docker --load -t openrv_rocky9.
```
## 4. Copy your OpenRV build from the docker
Run the below command to copy the OpenRV build from the docker to your current work directory.
```
docker run --name openrv_container -d openrv_rocky9 tail -f /dev/null
BUILD_NAME=$(docker exec openrv_container /bin/bash -c "source /etc/environment && echo \${BUILD_NAME}")
docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz $PWD/
docker stop openrv_container
docker rm -f openrv_container
```

## 5. Untar and test your OpenRV build
Use the tar command to decompress your OpenRV build and start up openRV:
```
tar -xvf OpenRV-Rocky9-x86_64-2.0.0.tar.gz
cd OpenRV-Rocky9-x86_64-2.0.0/bin
./rv
```
You should see your shiny new build of openRV!

## 6. Clean up
If everything went well with your docker build you can remove the files to free disk space with the following commands:
List all containers and images:
```
docker system df -v
docker ps -a
```
Delete the files associated with this build to free up drive space

```
docker stop openrv_container
docker rm openrv_container
docker rmi openrv_rocky9
```
## 7. Trouble shooting.
This is my first time with docker, just getting used to it so I'm leaving a few notes for future self.
If you need to trouble shoot your docker during the build you can get a shell like this:
```
docker run -it openrv_rocky9 /bin/bash

```
