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
    flex \
    build-essential \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    && dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y \
    libssl-dev:arm64 \
    && apt-get clean

RUN wget https://download.qt.io/archive/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz \
    && tar -xf qt-everywhere-src-5.15.2.tar.xz \
    && rm qt-everywhere-src-5.15.2.tar.xz

RUN mkdir -p arm64/sysroot 

COPY --from=sysroot /lib arm64/sysroot/lib
COPY --from=sysroot /usr/include arm64/sysroot/usr/include
COPY --from=sysroot /usr/lib arm64/sysroot/usr/lib
COPY --from=sysroot /usr/lib/aarch64-linux-gnu arm64/sysroot/usr/lib/aarch64-linux-gnu
COPY --from=sysroot /usr/include/openssl /arm64/sysroot/usr/include/openssl
COPY --from=sysroot /usr/lib/aarch64-linux-gnu/libssl* /arm64/sysroot/usr/lib/aarch64-linux-gnu/
COPY --from=sysroot /usr/lib/aarch64-linux-gnu/libcrypto* /arm64/sysroot/usr/lib/aarch64-linux-gnu/

# Fix some errors
RUN sed -i '45s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qglobal.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qfloat16.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qendian.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/text/qbytearraymatcher.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/tools/qoffsetstringarray_p.h
    
RUN cp /usr/include/aarch64-linux-gnu/openssl/opensslconf.h /qt/arm64/sysroot/usr/include/openssl \
    && cp /usr/include/aarch64-linux-gnu/openssl/configuration.h /qt/arm64/sysroot/usr/include/openssl

# Compile Qt for aarch64
RUN cd qt-everywhere-src-5.15.2 \ 
    && ./configure \
    -release \
    -sysroot /arm64/sysroot \
    -prefix /Qt/5.15.2/arm64 \
    -xplatform linux-aarch64-gnu-g++ \
    -device-option CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
    -opensource \
    -confirm-license \
    -openssl \
    -I/qt/arm64/sysroot/usr/include \
    -no-eglfs \
    -no-opengl \
    -no-use-gold-linker \
    -nomake tests \
    -no-pch \
    -skip qtlocation \
    -skip qtscript \
    -skip qtwayland \
    -skip qtdatavis3d \
    -v \
    && make -j$(nproc) && make install

### STAGE 3: final ###

FROM debian:bookworm-slim

WORKDIR /Qt

RUN apt-get update && apt-get install -y \
    python-is-python3 \
    python-dev-is-python3 \
    build-essential \
    libssl-dev \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    && apt-get clean

RUN mkdir /arm64

COPY --from=builder /arm64/sysroot/Qt /Qt
COPY --from=builder /qt/arm64 /arm64

ENV PATH=/Qt/5.15.2/arm64/bin:$PATH

WORKDIR /qt-app

CMD ["/bin/bash"]