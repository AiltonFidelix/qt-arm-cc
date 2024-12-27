### STAGE 1: Build ###

FROM debian:bookworm-slim AS builder

WORKDIR /qt

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

RUN mkdir -p rpi/sysroot 

COPY rpi3-lib.tar.gz .
COPY rpi3-usr.tar.gz .

RUN tar -xvzf rpi3-lib.tar.gz -C rpi/sysroot \
    && rm rpi3-lib.tar.gz

RUN tar -xvzf rpi3-usr.tar.gz -C rpi/sysroot \
    && rm rpi3-usr.tar.gz

RUN wget https://download.qt.io/archive/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz \
    && tar -xf qt-everywhere-src-5.15.2.tar.xz \
    && rm qt-everywhere-src-5.15.2.tar.xz

RUN sed -i '45s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qglobal.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qfloat16.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/global/qendian.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/text/qbytearraymatcher.h \
    && sed -i '1s/^/#include <limits>\n /' qt-everywhere-src-5.15.2/qtbase/src/corelib/tools/qoffsetstringarray_p.h

RUN cd qt-everywhere-src-5.15.2 \ 
    && ./configure \
    -release \
    -sysroot /rpi/sysroot \
    -prefix /Qt/5.15.2/armhf32 \
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

RUN mkdir /rpi

COPY --from=builder /rpi/sysroot/Qt /Qt
COPY --from=builder /qt/rpi /rpi

ENV PATH=/Qt/5.15.2/armhf32/bin:$PATH

CMD  ["/bin/bash"]