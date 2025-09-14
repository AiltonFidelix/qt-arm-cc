### STAGE 1: sysroot ###

FROM --platform=linux/arm64 debian:bookworm-slim AS sysroot

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    wget \
    unzip \
    tar \
    libssl-dev \
    libicu-dev \
    libc6-dev \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    libgl-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxrender-dev \
    libxcb1-dev \
    libxcb-glx0-dev \
    libxcb-keysyms1-dev \
    libxcb-image0-dev \
    libxcb-shm0-dev \
    libxcb-icccm4-dev \
    libxcb-sync-dev \
    libxcb-xfixes0-dev \
    libxcb-shape0-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxcb-cursor0 \
    libxcb-cursor-dev \
    python-is-python3 \
    python-dev-is-python3 \
    && rm -rf /var/lib/apt/lists/

# Install Raspberry Pi wiringpi library (optional) 
RUN wget https://github.com/WiringPi/WiringPi/releases/download/3.16/wiringpi_3.16_arm64.deb \
    && dpkg -i wiringpi_3.16_arm64.deb \
    && rm wiringpi_3.16_arm64.deb

# Install Paho MQTT library (optional) 
RUN git clone https://github.com/eclipse-paho/paho.mqtt.cpp \
    && cd paho.mqtt.cpp \
    && git checkout v1.5.1 \
    && git submodule update --init --recursive \
    && cmake -Bbuild -S. \
    -DPAHO_WITH_MQTT_C=ON \
    -DOPENSSL_ROOT_DIR=/usr \
    -DOPENSSL_INCLUDE_DIR=/usr/include \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/lib/aarch64-linux-gnu/libcrypto.so \
    -DOPENSSL_SSL_LIBRARY=/usr/lib/aarch64-linux-gnu/libssl.so \
    && cmake --build build/ --target install

# Install GoogleTest library (optional) 
RUN git clone https://github.com/google/googletest \
    && cd googletest \
    && git checkout v1.16.0 \
    && cmake -Bbuild -H. \
    && cmake --build build/ --target install

### STAGE 2: builder ###

FROM debian:bookworm-slim AS builder

WORKDIR /qt

# Install host packages
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    tar \
    git \
    python-is-python3 \
    python-dev-is-python3 \
    bison \
    gperf \
    pkg-config \
    libclang-dev \
    libssl-dev \
    libicu-dev \
    libgl-dev \
    libglu1-mesa-dev \
    mesa-common-dev \
    libegl-dev \
    libgles-dev \
    flex \
    cmake \
    ninja-build \
    build-essential \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    && dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y \
    libssl-dev:arm64 \
    && apt-get clean

RUN wget https://download.qt.io/archive/qt/6.8/6.8.3/single/qt-everywhere-src-6.8.3.tar.xz \
    && tar -xf qt-everywhere-src-6.8.3.tar.xz \
    && rm qt-everywhere-src-6.8.3.tar.xz

RUN mkdir -p arm64/sysroot 

COPY --from=sysroot /lib arm64/sysroot/lib
COPY --from=sysroot /usr/include/ arm64/sysroot/usr/include/
COPY --from=sysroot /usr/local/include/ arm64/sysroot/usr/include/
COPY --from=sysroot /usr/lib arm64/sysroot/usr/lib
COPY --from=sysroot /usr/local/lib arm64/sysroot/usr/local/lib
COPY --from=sysroot /usr/lib/aarch64-linux-gnu arm64/sysroot/usr/lib/aarch64-linux-gnu
COPY --from=sysroot /usr/include/openssl /arm64/sysroot/usr/include/openssl
COPY --from=sysroot /usr/lib/aarch64-linux-gnu/libssl* /arm64/sysroot/usr/lib/aarch64-linux-gnu/
COPY --from=sysroot /usr/lib/aarch64-linux-gnu/libcrypto* /arm64/sysroot/usr/lib/aarch64-linux-gnu/

RUN cp /usr/include/aarch64-linux-gnu/openssl/opensslconf.h /qt/arm64/sysroot/usr/include/openssl \
    && cp /usr/include/aarch64-linux-gnu/openssl/configuration.h /qt/arm64/sysroot/usr/include/openssl

COPY aarch64-toolchain.cmake .

# Compile Qt for host
RUN cd qt-everywhere-src-6.8.3 \ 
    && mkdir build-host \
    && cd build-host \
    && ../configure \
    -release \
    -opensource \
    -confirm-license \
    -prefix /Qt/6.8.3/host \
    -skip qtwebengine -skip qtpdf \
    -no-warnings-are-errors \
    && cmake --build . --parallel 12 \
    && cmake --install .

# Compile Qt for aarch64
RUN cd qt-everywhere-src-6.8.3 \ 
    && mkdir build-aarch64 \
    && cd build-aarch64 \
    && ../configure \
    -release \
    -opengl es2 \
    -opensource \
    -confirm-license \
    -prefix /Qt/6.8.3/arm64 \
    -extprefix /Qt/6.8.3/arm64 \
    -sysroot /qt/arm64/sysroot \
    -qt-host-path /Qt/6.8.3/host \
    -xplatform linux-aarch64-gnu-g++ \
    -device-option CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
    -nomake examples -nomake tests \
    -skip qtwebengine -skip qtpdf \
    -no-warnings-are-errors \
    -- \
    -DCMAKE_TOOLCHAIN_FILE=/qt/aarch64-toolchain.cmake \
    -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON \
    && cmake --build . --parallel 12 \
    && cmake --install .

### STAGE 3: final ###

FROM debian:bookworm-slim

WORKDIR /Qt

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    tar \
    git \
    file \
    python-is-python3 \
    python-dev-is-python3 \
    build-essential \
    libssl-dev \
    cmake \
    ninja-build \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    && apt-get clean

RUN mkdir /arm64

COPY --from=builder /Qt /Qt
COPY --from=builder /qt/arm64 /qt/arm64
COPY --from=builder /qt/aarch64-toolchain.cmake /qt/aarch64-toolchain.cmake

ENV PATH=/Qt/6.8.3/arm64/bin:$PATH \
    LD_LIBRARY_PATH=/qt/arm64/sysroot/lib:/qt/arm64/sysroot/usr/local/lib:$LD_LIBRARY_PATH

WORKDIR /qt-app

COPY examples /qt-app/examples

CMD ["/bin/bash"]