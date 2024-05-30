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

# Ensure Buildx is installed
docker buildx install
docker buildx create --use
docker buildx inspect --bootstrap

# Build Docker image
docker buildx build --load --build-arg QT_USER=${QT_USER} --build-arg QT_PASSWORD=${QT_PASSWORD} -t openrv_rocky9 .

# Run the container to copy the tarball
docker run -d --name openrv_container openrv_rocky9
BUILD_NAME=$(docker exec openrv_container /bin/bash -c "source /etc/environment && echo \${BUILD_NAME}")
docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz $PWD/

echo "Build completed. The OpenRV build has been copied to $PWD/${BUILD_NAME}.tar.gz"
