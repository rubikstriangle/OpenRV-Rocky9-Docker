#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -u <QT_USER> -p <QT_PASSWORD>"
    exit 1
}

# Parse arguments
while getopts "u:p:" opt; do
    case $opt in
        u) QT_USER=$OPTARG ;;
        p) QT_PASSWORD=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if QT_USER and QT_PASSWORD are set
if [ -z "$QT_USER" ] || [ -z "$QT_PASSWORD" ]; then
    usage
fi

# Check if QT_USER and QT_PASSWORD are not placeholder values
if [ "$QT_USER" == "your_qt_username" ] || [ "$QT_PASSWORD" == "your_qt_password" ]; then
    echo "Error: QT_USER and QT_PASSWORD cannot be the placeholder values from the README file."
    usage
fi

# Ensure Buildx is installed
#docker buildx install
#docker buildx create --use
#docker buildx inspect --bootstrap

# Build Docker image
docker build --load --build-arg QT_USER=${QT_USER} --build-arg QT_PASSWORD=${QT_PASSWORD} -t openrv_rocky9 .


# Verify the target container has been stopped 
if [ "$(docker ps -q --filter name=^openrv_cont$)" ]; then
    docker stop openrv_cont
    echo "Stopped the container openrv_container"
fi
# Verify target container doesn't exist and remove if it does
if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    docker rm -f openrv_container
    echo "Removed docker container openrv_container"
fi

# Run the container
echo "Running the container openrv_container...."
docker run --name openrv_container -d openrv_rocky9 tail -f /dev/null

echo "Retrieving the OpenRV build name from the docker image"

BUILD_NAME=$(docker exec openrv_container /bin/bash -c "source /etc/environment && echo \${BUILD_NAME}")

echo "Copying the OpenRV build name from the docker image"

docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz $PWD/

if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    echo "Build completed. The OpenRV build has been copied to $PWD/${BUILD_NAME}.tar.gz"
else
    echo "Build failed. The file /OpenRV/${BUILD_NAME} is not present."
    docker rm openrv_cont
    exit 1
fi

# Verify the target container has been stopped 
if [ "$(docker ps -q --filter name=^openrv_cont$)" ]; then
    docker stop openrv_container
    echo "Stopped the container openrv_container"
fi

# Verify target container doesn't exist and remove if it does
if [ "$(docker ps -aq --filter name=^openrv_container$)" ]; then
    docker rm -f openrv_container
    echo "Removed docker container openrv_container"
fi


