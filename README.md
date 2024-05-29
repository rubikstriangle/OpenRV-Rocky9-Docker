# OpenRV-Rocky9-Docker
A dockerfile to build OpenRV with a rocky 9 docker based on OpenRV from https://github.com/AcademySoftwareFoundation/OpenRV.git
In my case I'm building OpenRV to run on Ubuntu 22.04 but it should work just as well for other linux distributions.

## 1. Install Docker
https://docs.docker.com/engine/install

# Build OpenRV with this Dockerfile
## 2. Clone this repository
```
git clone https://github.com/rubikstriangle/OpenRV-Rocky9-Docker
cd OpenRV-Rocky9-Docker
```
## 3. Build image from this Dockerfile
Build the image from the `OpenRV-Dockerfile` directory, swap out your qt login info on this step. If you don't have an account you can get a free account here https://login.qt.io/register 
```
QT_USER=your_qt_username
QT_PASSWORD=your_qt_password
docker build --build-arg QT_USER=${QT_USER} --build-arg QT_PASSWORD=${QT_PASSWORD} -t openrv_rocky9 .
```
You may have to use sudo, depending on your configuration.
If you get a cmake error "Could not find a package configuration file provided by "Qt5WebEngineCore" your qt install failed check step 9 of 22 in the docker install for the reason why.  If you get the warning "Maximum number of Qt installation reached", you need to login to your qt account (https://account.qt.io/s/active-installation-list) and delete some of your installs, other wise check your user name and password.

## 4. Run the docker openrv image
Run the docker image
```
sudo docker run -d --name openrv_rocky9 openrv_build

```
## 5. Copy your OpenRV build from the docker
The last few lines of your docker build should have printed out a cyan line which is a dynamically generated name of the tarball of your OpenRV build.  Copy the cyan line in your shell to copy the OpenRV build to your ~/Downloads folder.  The below command should work for version 2.0.0
```
sudo docker cp openrv_build:/OpenRV/OpenRV-Rocky9-x86_64-2.0.0.tar.gz ~/Downloads/
```
## 6. Untar your OpenRV build
Use the tar command to decompress your OpenRV build
```
tar -xvf ~/Downloads/OpenRV-Rocky9-x86_64-2.0.0.tar.gz
```
