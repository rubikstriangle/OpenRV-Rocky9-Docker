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

# Define Dockerfile content
DOCKERFILE_CONTENT=$(cat <<EOF
FROM amd64/rockylinux:9.1

ENV HOME /root
WORKDIR \$HOME

# Update PATH to include /root/.local/bin
ENV PATH=\$HOME/.local/bin:\$PATH

# Install base packages and additional development tools
RUN dnf install -y git wget diffutils epel-release alsa-lib-devel autoconf automake avahi-compat-libdns_sd-devel bison bzip2-devel cmake-gui curl-devel flex gcc gcc-c++ iproute libXcomposite libXi-devel libaio-devel libffi-devel nasm ncurses-devel nss libtool libxkbcommon libXcomposite libXdamage libXrandr libXtst libXcursor meson ninja-build openssl openssl-devel perl-FindBin pulseaudio-libs pulseaudio-libs-glib2 ocl-icd ocl-icd-devel opencl-headers python3 python3-devel qt5-qtbase-devel qt5-qttools-devel readline-devel sqlite-devel tcl-devel tcsh tk-devel yasm zip zlib-devel mesa-libGLU mesa-libGLU-devel mesa-libOSMesa mesa-libOSMesa-devel glew-devel libXi-devel libXmu-devel mesa-libGL-devel freeglut-devel xorg-x11-server-devel opencv opencv-devel patch openssh-server gdbm-devel libuuid-devel libnsl2-devel \
    && dnf clean all

# Set the build arguments for Qt login credentials
ARG QT_USER
ARG QT_PASSWORD

# Download Qt installer script
RUN wget https://qt.mirror.constant.com/archive/online_installers/4.4/qt-unified-linux-x64-4.4.2-online.run -O /tmp/qt-installer.run \
    && echo "expected-checksum-value /tmp/qt-installer.run" | sha256sum -c - \
    && chmod +x /tmp/qt-installer.run

# Install Qt with debug information and check for the "Maximum number of Qt installation reached" message
RUN set -e; \
    QT_INSTALL_LOG=\$(mktemp); \
    /tmp/qt-installer.run --email \${QT_USER} --root \$HOME/Qt --password \${QT_PASSWORD} --platform minimal --accept-licenses --confirm-command install qt.qt5.5152.qtpdf qt.qt5.5152.qtpurchasing qt.qt5.5152.qtvirtualkeyboard qt.qt5.5152.qtquicktimeline qt.qt5.5152.qtlottie qt.qt5.5152.debug_info qt.qt5.5152.qtscript qt.qt5.5152.qtcharts qt.qt5.5152.qtwebengine > \$QT_INSTALL_LOG 2>&1

# Clone the OpenRV repository and build OpenRV
RUN git clone --recursive https://github.com/AcademySoftwareFoundation/OpenRV.git /OpenRV
WORKDIR /OpenRV
RUN pip install --upgrade pip
RUN python3 -m pip install --user --upgrade -r /OpenRV/requirements.txt
RUN cmake -B /OpenRV/_build -G Ninja -DCMAKE_BUILD_TYPE=Release -DRV_DEPS_QT5_LOCATION=/root/Qt/5.15.2/gcc_64
RUN cmake --build /OpenRV/_build --config Release -v --parallel=128 --target main_executable

# Determine build platform, version, and architecture and write to a file
RUN echo "Determining build platform..." && \
    if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "\$NAME" = "Rocky Linux" ]; then \
            BUILD_PLATFORM="Rocky\${VERSION_ID%.*}"; \
        else \
            BUILD_PLATFORM=\$(echo \${NAME}\${VERSION_ID} | tr ' ' '_'); \
        fi \
    else \
        BUILD_PLATFORM=\$(uname -s); \
    fi && \
    VERSION=\$(/OpenRV/_build/stage/app/bin/rv -version) && \
    ARCHITECTURE=\$(uname -m) && \
    echo "BUILD_PLATFORM=\$BUILD_PLATFORM" > /etc/environment && \
    echo "VERSION=\$VERSION" >> /etc/environment && \
    echo "ARCHITECTURE=\$ARCHITECTURE" >> /etc/environment && \
    BUILD_NAME=OpenRV-\${BUILD_PLATFORM}-\${ARCHITECTURE}-\${VERSION} && \
    echo "BUILD_NAME=\$BUILD_NAME" >> /etc/environment

# Source the environment variables file and create the tarball
RUN . /etc/environment && echo "Build Name: \$BUILD_NAME"
RUN . /etc/environment && cmake --install /OpenRV/_build --prefix /OpenRV/\${BUILD_NAME} --config Release
RUN . /etc/environment && cp /lib64/libcrypt.so.2 /OpenRV/\${BUILD_NAME}/lib
RUN . /etc/environment && tar -czvf \${BUILD_NAME}.tar.gz -C /OpenRV \${BUILD_NAME}

# Print instructions for copying the build tarball
RUN . /etc/environment && echo -e "\n\e[1;32mRun the following lines to copy your OpenRV build into your ~/Downloads folder:\e[0m" && \
    echo -e "\e[1;36msudo docker run -d --name openrv_container openrv_rocky9\e[0m" && \
    echo -e "\e[1;36msudo docker cp openrv_container:/OpenRV/\${BUILD_NAME}.tar.gz ~/Downloads/\e[0m\n\n"
EOF
)

# Create Dockerfile
echo "$DOCKERFILE_CONTENT" > Dockerfile

# Build Docker image
docker build --build-arg QT_USER=${QT_USER} --build-arg QT_PASSWORD=${QT_PASSWORD} -t openrv_rocky9 .

# Run the container to copy the tarball
docker run -d --name openrv_container openrv_rocky9
BUILD_NAME=$(docker exec openrv_container /bin/bash -c "source /etc/environment && echo \${BUILD_NAME}")
docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz ~/Downloads/

echo "Build completed. The OpenRV build has been copied to ~/Downloads/${BUILD_NAME}.tar.gz"

