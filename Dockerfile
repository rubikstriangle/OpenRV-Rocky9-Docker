FROM amd64/rockylinux:9

ENV HOME /root
WORKDIR $HOME

# Update PATH to include /root/.local/bin
ENV PATH=$HOME/.local/bin:$PATH

# Install base packages and additional development tools
RUN dnf install -y git wget diffutils epel-release \
    && dnf config-manager --set-enabled crb devel \
    && dnf install -y expect alsa-lib-devel autoconf automake avahi-compat-libdns_sd-devel bison bzip2-devel cmake-gui curl-devel flex gcc gcc-c++ iproute libXcomposite libXi-devel libaio-devel libffi-devel nasm ncurses-devel nss libtool libxkbcommon libXcomposite libXdamage libXrandr libXtst libXcursor meson ninja-build openssl openssl-devel perl-FindBin pulseaudio-libs pulseaudio-libs-glib2 ocl-icd ocl-icd-devel opencl-headers python3 python3-devel qt5-qtbase-devel qt5-qttools-devel readline-devel sqlite-devel tcl-devel tcsh tk-devel yasm zip zlib-devel mesa-libGLU mesa-libGLU-devel mesa-libOSMesa mesa-libOSMesa-devel glew-devel libXi-devel libXmu-devel mesa-libGL-devel freeglut-devel xorg-x11-server-devel opencv opencv-devel patch openssh-server gdbm-devel libuuid-devel libnsl2-devel \
    && dnf config-manager --set-disabled devel \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && dnf clean all

# Set the build arguments for Qt login credentials
ARG QT_USER
ARG QT_PASSWORD

#Install Qt
COPY accept_license.exp /tmp/accept_license.exp
RUN chmod +x /tmp/accept_license.exp
RUN wget https://download.qt.io/archive/online_installers/4.2/qt-unified-linux-x64-4.2.0-online.run -O /tmp/qt-installer.run && \
    chmod +x /tmp/qt-installer.run && \
    /tmp/accept_license.exp && \
    /root/Qt/5.15.2/gcc_64/bin/qmake --version || { echo "Qt installation failed"; exit 1; } && \
    rm /tmp/qt-installer.run

# Install OpenRV
RUN git clone --recursive https://github.com/AcademySoftwareFoundation/OpenRV.git /OpenRV
WORKDIR /OpenRV
RUN pip install --upgrade pip
RUN python3 -m pip install --user --upgrade -r /OpenRV/requirements.txt
RUN cmake -B /OpenRV/_build -G Ninja -DCMAKE_BUILD_TYPE=Release -DRV_DEPS_QT5_LOCATION=/root/Qt/5.15.2/gcc_64
RUN cmake --build /OpenRV/_build --config Release -v --parallel=128 --target main_executable


# Determine build platform, version, and architecture for creation of rv tarball name
RUN echo "Determining build platform..." && \
    if [ -f /etc/os-release ]; then \
        . /etc/os-release; \
        if [ "$NAME" = "Rocky Linux" ]; then \
            BUILD_PLATFORM="Rocky${VERSION_ID%.*}"; \
        else \
            BUILD_PLATFORM=$(echo ${NAME}${VERSION_ID} | tr ' ' '_'); \
        fi \
    else \
        BUILD_PLATFORM=$(uname -s); \
    fi && \
    VERSION=$(/OpenRV/_build/stage/app/bin/rv -version) && \
    ARCHITECTURE=$(uname -m) && \
    echo "BUILD_PLATFORM=$BUILD_PLATFORM" > /etc/environment && \
    echo "VERSION=$VERSION" >> /etc/environment && \
    echo "ARCHITECTURE=$ARCHITECTURE" >> /etc/environment && \
    BUILD_NAME=OpenRV-${BUILD_PLATFORM}-${ARCHITECTURE}-${VERSION} && \
    echo "BUILD_NAME=$BUILD_NAME" >> /etc/environment && \
    echo "$BUILD_NAME" >> /OpenRV/build_name.txt
    
# Source the environment variables file
RUN . /etc/environment && echo "Build Name: $BUILD_NAME"
RUN . /etc/environment && cmake --install /OpenRV/_build --prefix /OpenRV/${BUILD_NAME} --config Release
RUN . /etc/environment && cp /lib64/libcrypt.so.2 /OpenRV/${BUILD_NAME}/lib
RUN . /etc/environment && tar -czvf ${BUILD_NAME}.tar.gz -C /OpenRV ${BUILD_NAME}
RUN . /etc/environment && echo -e "\n\e[1;32mRun the following lines to copy your OpenRV build into your ~/Downloads folder:\e[0m" && \
    echo -e "\e[1;36msudo docker run -d --name openrv_container openrv_rocky9\e[0m" && \
    echo -e "\e[1;36msudo docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz ~/Downloads/\e[0m\n\n"
