### STAGE 1: sysroot ###

FROM --platform=linux/arm64 debian:bookworm-slim AS sysroot

RUN apt-get update && apt-get install -y \
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
    python-is-python3 \
    python-dev-is-python3

RUN dpkg --add-architecture armhf \
    && apt update && apt install -y \
    libc6:armhf \
    libstdc++6:armhf \
    libgcc1:armhf

### STAGE 2: builder ###

FROM debian:bookworm-slim AS builder

WORKDIR /qt

# Install host packages
RUN apt-get update && apt-get install -y \
    wget \
    tar \
    python-is-python3 \
    python-dev-is-python3 \
    bison \
    gperf \
    pkg-config \
    libclang-dev \
    build-essential \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    && apt-get clean

RUN mkdir -p arm32/sysroot 

COPY --from=sysroot /lib arm32/sysroot/lib
COPY --from=sysroot /usr/include arm32/sysroot/usr/include
COPY --from=sysroot /usr/lib arm32/sysroot/usr/lib
COPY --from=sysroot /usr/lib/arm-linux-gnueabihf arm32/sysroot/usr/lib/arm-linux-gnueabihf   

RUN wget https://download.qt.io/archive/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz \
    && tar -xf qt-everywhere-src-5.15.2.tar.xz \
    && rm qt-everywhere-src-5.15.2.tar.xz

# Fix some errors
RUN sed -i '45s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qglobal.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qfloat16.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qendian.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/text/qbytearraymatcher.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/tools/qoffsetstringarray_p.h

# TODO: Add openssl support

# Compile Qt for armhf
RUN cd qt-everywhere-src-5.15.2 \ 
    && ./configure \
    -release \
    -sysroot /arm32/sysroot \
    -prefix /Qt/5.15.2/arm32 \
    -device-option CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- \
    -device linux-rasp-pi3-g++ \
    -opensource \
    -confirm-license \
    -no-eglfs \
    -no-opengl \
    -no-use-gold-linker \
    -nomake tests \
    -skip qtlocation \
    -skip qtscript \
    -skip qtwayland \
    -skip qtdatavis3d \
    -v \ 
    && make -j$(nproc) && make install

### STAGE 2: final ###

FROM debian:bookworm-slim

WORKDIR /Qt

RUN apt-get update && apt-get install -y \
    python-is-python3 \
    python-dev-is-python3 \
    build-essential \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    && apt-get clean

RUN mkdir /arm32

COPY --from=builder /arm32/sysroot/Qt /Qt
COPY --from=builder /qt/arm32 /arm32

ENV PATH=/Qt/5.15.2/arm32/bin:$PATH

WORKDIR /qt-app

CMD  ["/bin/bash"]