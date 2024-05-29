# OpenRV-Rocky9-Docker
A Dockerfile to build OpenRV with a Rocky 9 base, based on [OpenRV](https://github.com/AcademySoftwareFoundation/OpenRV.git). This setup is tested on Ubuntu 22.04 but should work just as well for other Linux distributions.



## 1. Install Docker
Follow the instructions on the official Docker documentation to install Docker on your machine: [Install Docker](https://docs.docker.com/engine/install)

## 2. Clone this repository
```
git clone https://github.com/rubikstriangle/OpenRV-Rocky9-Docker
cd OpenRV-Rocky9-Docker
```
## 3. Build image from this Dockerfile
Build the image from the OpenRV-Rocky9-Docker directory. Replace your_qt_username and your_qt_password with your actual Qt login credentials. If you don't have an account, you can get a free account [here](https://login.qt.io/register).

```
QT_USER=your_qt_username
QT_PASSWORD=your_qt_password
docker build --build-arg QT_USER=${QT_USER} --build-arg QT_PASSWORD=${QT_PASSWORD} -t openrv_rocky9 .
```
Note: You may need to use sudo, depending on your configuration.

#### Troubleshooting

- CMake Error: If you encounter a CMake error "Could not find a package configuration file provided by 'Qt5WebEngineCore'", your Qt installation likely failed. Check step 9 of 22 in the Docker build process for the reason why.
- Qt Installation Warning: If you get the warning "Maximum number of Qt installations reached", log in to your [qt account](https://account.qt.io/s/active-installation-list) and delete some of your existing installations. Ensure your username and password are correct.

## 4. Copy your OpenRV build from the docker
The last few lines of your docker build should have printed out a cyan line which is a dynamically generated name of the tarball of your OpenRV build.  Copy the cyan line in your shell to copy the OpenRV build to your ~/Downloads folder.  The below command should work for version 2.0.0
```
sudo docker run -d --name openrv_rocky9 openrv_build
sudo docker cp openrv_build:/OpenRV/OpenRV-Rocky9-x86_64-2.0.0.tar.gz ~/Downloads/
```
## 5. Untar your OpenRV build
Use the tar command to decompress your OpenRV build
```
tar -xvf ~/Downloads/OpenRV-Rocky9-x86_64-2.0.0.tar.gz
```
