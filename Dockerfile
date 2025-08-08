FROM rockylinux/rockylinux:9

LABEL maintainer="Open RV maintainer - https://github.com/AcademySoftwareFoundation/OpenRV"

USER root


# static versions:
ENV CMAKE_VERSION="3.31.6" \
    NINJA_VERSION="1.12.1"

# ─────────────────────────────────────────────
# CY2024 Configuration
# ─────────────────────────────────────────────
ENV VFX_PLATFORM="CY2024" \
    PYTHON_VERSION="3.11.8" \
    QT_VERSION="6.5.3" \
    QT_MODULES="debug_info qt3d qt5compat qtcharts qtconnectivity qtdatavis3d qtgrpc qthttpserver qtimageformats qtlanguageserver qtlocation qtlottie qtmultimedia qtnetworkauth qtpdf qtpositioning qtquick3d qtquick3dphysics qtquickeffectmaker qtquicktimeline qtremoteobjects qtscxml qtsensors qtserialbus qtserialport qtshadertools qtspeech qtvirtualkeyboard qtwaylandcompositor qtwebchannel qtwebengine qtwebsockets qtwebview" \
    QT_ARCHIVES="icu qtbase qtdeclarative qtsvg qttools qttranslations qtwayland"

# Install tools and build dependencies
RUN dnf upgrade -y \
    && dnf install -y epel-release \
    && dnf config-manager --set-enabled crb devel \
    && dnf install -y perl-CPAN

RUN cpan FindBin
    
RUN dnf groupinstall "Development Tools" -y \
    && dnf install -y \
    # RV requirements
    alsa-lib-devel \
    autoconf \
    automake \
    avahi-compat-libdns_sd-devel \
    bison \
    bzip2-devel \
    cmake-gui \
    curl-devel \
    flex \
    gcc \
    gcc-c++ \
    git \
    libX11-devel \
    libXcomposite \
    libXcomposite-devel \
    libXcursor \
    libXcursor-devel \
    libXdamage \
    libXext-devel \
    libXi-devel \
    libXi-devel \
    libXrandr \
    libXrandr-devel \
    libXrender-devel \
    libXtst \
    libXxf86vm-devel \
    libaio-devel \
    libffi-devel \
    libtool \
    libxkbcommon \
    libxkbcommon-devel \
    libxkbfile \
    mesa-libGLU \
    mesa-libGLU-devel \
    mesa-libOSMesa \
    mesa-libOSMesa-devel \
    meson \
    nasm \
    ncurses-devel \
    nss \
    ocl-icd \
    ocl-icd-devel \
    opencl-headers \
    openssl-devel \
    patch \
    patchelf \
    pcsc-lite \
    perl-FindBin \
    perl-IPC-Cmd \
    pulseaudio-libs \
    pulseaudio-libs-glib2 \
    qt5-qtbase-devel \
    readline-devel \
    sqlite-devel \
    systemd-devel \
    tcl-devel \
    tcsh \
    tk-devel \
    wget \
    xz-devel \
    yasm \
    zip \
    zlib-devel \
    && dnf clean all

# Disable the devel repo afterwards since dnf will warn about it
RUN dnf config-manager --set-disabled devel

# Install CMake
RUN curl -L https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh -o cmake.sh && \
    sh cmake.sh --prefix=/usr/local/ --skip-license && \
    rm -rf cmake.sh

# Create and run as user rv
RUN useradd -u 1001 -ms /bin/bash rv
WORKDIR /home/rv
USER rv

ENV PATH=/home/rv/.local/bin:/usr/local/bin:$PATH \
    QT_QPA_PLATFORM=offscreen 

# Install Ninja
RUN wget https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip && \
    unzip ninja-linux.zip -d ./ninja && \
    echo 'export PATH=/home/rv/ninja:$PATH' >> /home/rv/.bash_profile
ENV PATH /home/rv/ninja:$PATH

# Install pyenv
RUN git clone http://github.com/pyenv/pyenv.git /home/rv/.pyenv
ENV PYENV_ROOT /home/rv/.pyenv
ENV PATH $PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
RUN echo 'export PYENV_ROOT="/home/rv/.pyenv"' >> ~/.bashrc && \
    echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc

# Python environment
RUN pyenv install ${PYTHON_VERSION}
RUN pyenv global ${PYTHON_VERSION}

RUN python -m pip install aqtinstall

# Install Qt
RUN python -m aqt install-qt linux desktop ${QT_VERSION} gcc_64 -O ~/Qt \
-m ${QT_MODULES} \
--archives ${QT_ARCHIVES}


# Install OpenRV
RUN git clone --recursive https://github.com/AcademySoftwareFoundation/OpenRV.git /home/rv/OpenRV/
WORKDIR /home/rv/OpenRV/
RUN python3 -m venv .venv
RUN source /home/rv/OpenRV/.venv/bin/activate
RUN pip install --upgrade pip
RUN python3 -m pip install --user --upgrade -r /home/rv/OpenRV/requirements.txt
RUN cmake -B /home/rv/OpenRV/_build -G Ninja -DCMAKE_BUILD_TYPE=Release -DRV_DEPS_QT6_LOCATION=/home/rv/Qt/6.5.3/gcc_64 -DRV_VFX_PLATFORM=CY2024 -DRV_DEPS_WIN_PERL_ROOT=
RUN cmake --build /home/rv/OpenRV/_build --config Release -v --parallel=128 --target main_executable


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
    VERSION=$(/home/rv/OpenRV/_build/stage/app/bin/rv -version) && \
    ARCHITECTURE=$(uname -m) && \
    echo "BUILD_PLATFORM=$BUILD_PLATFORM" > /home/rv/OpenRV/environment && \
    echo "VERSION=$VERSION" >> /home/rv/OpenRV/environment && \
    echo "ARCHITECTURE=$ARCHITECTURE" >> /home/rv/OpenRV/environment && \
    BUILD_NAME=OpenRV-${BUILD_PLATFORM}-${ARCHITECTURE}-${VERSION} && \
    echo "BUILD_NAME=$BUILD_NAME" >> /home/rv/OpenRV/environment && \
    echo "$BUILD_NAME" >> /home/rv/OpenRV/build_name.txt
    
# Source the environment variables file
RUN . /home/rv/OpenRV/environment && echo "Build Name: $BUILD_NAME"
RUN . /home/rv/OpenRV/environment && cmake --install /home/rv/OpenRV/_build --prefix /home/rv/OpenRV/${BUILD_NAME} --config Release
RUN . /home/rv/OpenRV/environment && cp /lib64/libcrypt.so.2 /home/rv/OpenRV/${BUILD_NAME}/lib
RUN . /home/rv/OpenRV/environment && tar -czvf ${BUILD_NAME}.tar.gz -C /home/rv/OpenRV/ ${BUILD_NAME}
RUN . /home/rv/OpenRV/environment && echo -e "\n\e[1;32mRun the following lines to copy your OpenRV build into your ~/Downloads folder:\e[0m" && \
    echo -e "\e[1;36msudo docker run -d --name openrv_container openrv_rocky9\e[0m" && \
    echo -e "\e[1;36msudo docker cp openrv_container:/OpenRV/${BUILD_NAME}.tar.gz ~/Downloads/\e[0m\n\n"


#CMD ["/bin/bash"]