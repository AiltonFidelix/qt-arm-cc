# Qt 5.15.2 cross-compilation ARM

Configuração do cross-compilation para o Qt 5.15.2 para Raspberry Pi 3+.

## Pré requisitos

Antes de começar, verifique se você já possui os seguintes itens:

- Uma máquina linux (Ubuntu, Debian), de preferência instale o docker e use uma imagem Debian
- Qt 5.15.2 fontes 
- Toolchain para cross-compiling `gcc-arm-linux-gnueabihf` para ARMv7-A (32-bit) e `gcc-aarch64-linux-gnu` para ARMv8-A (64-bit)
- Raspberry Pi 3+ ou mais nova com Raspberry Pi OS 64-bit (utilizada para obter os arquivos necessários)
- QEMU para emulação (opcional)

**Observação:** Existem maneiras de preparar o ambiente usando o emulador, porém pode adicionar alguma complexibilidade. Neste manual iremos utilizar direto a Raspberry.

## Preparando a Raspberry Pi 3

Primeiro instale os pacotes necessários:

```bash
sudo apt-get update
sudo apt-get install -y \
  libpq-dev \
  libssl-dev \
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
  libxkbcommon-x11-dev
```

Depois instale os pacotes de compatibilidade com armhf:

```bash
sudo dpkg --add-architecture armhf
sudo apt update

sudo apt install libc6:armhf
sudo apt install libstdc++6:armhf
sudo apt install libgcc1:armhf
```

### 2. **Setting up the Cross-Compiler Toolchain**

First, install the cross-compiler toolchain for ARM.

Machine 

```bash
sudo apt-get update
sudo apt-get install -y \
  wget \
  tar \
  ssh \
  rsync \
  python-is-python3 \
  python-dev-is-python3 \
  bison \
  gperf \
  pkg-config \
  libclang-dev \
  build-essential \
  gcc-aarch64-linux-gnu \
  g++-aarch64-linux-gnu
  # gcc-arm-linux-gnueabihf \
  # g++-arm-linux-gnueabihf \
```

This will install the necessary tools to compile code for ARM.

### 3. **Download Qt 5.15 Source Code**

Next, download the Qt 5.15 source code. You can either clone the official Qt repository or download the tarball from the Qt website:

```bash
git clone --branch 5.15 https://code.qt.io/qt/qt5.git
cd qt5
```

Or, if using the tarball:

```bash
wget https://download.qt.io/archive/qt/5.15/5.15.2/single/qt-everywhere-src-5.15.2.tar.xz
tar -xf qt-everywhere-src-5.15.2.tar.xz
cd qt-everywhere-src-5.15.2
```

```
cd /
mkdir -p rpi/sysroot
```

### 4. **Setting up the Raspberry Pi Sysroot**

To cross-compile, you'll need the Raspberry Pi's libraries, headers, and other environment files (called a sysroot). There are a couple of options to get this sysroot:

- **Option 1: Copy from a running Raspberry Pi**  
    You can copy the sysroot from a Raspberry Pi running Raspbian using `rsync` or similar tools:

```bash
rsync -avz pi@192.168.x.x:/lib rpi/sysroot/
rsync -avz pi@192.168.x.x:/usr /rpi/sysroot/
rsync -avz pi@192.168.x.x:/usr/include rpi/sysroot/
```

- **Option 2: Use an already prepared sysroot**  
    If you don't want to create the sysroot yourself, you can search online for pre-configured sysroots.

### 5. **Configure Qt for Cross-Compilation**

With the cross-compiler toolchain and sysroot ready, configure the Qt build process. You will configure Qt to use the ARM cross-compiler, specify the sysroot, and the target architecture.

```bash
  # -device-option CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- \
  # -device-option CROSS_COMPILE=/usr/bin/aarch64-linux-gnu- \
./configure \
  -release \
  -prefix /opt/qt5.15 \
  -sysroot /rpi/sysroot \
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
  -v
```

qt5/mkspecs/devices/linux-rasp-pi3-g++/qmake.conf

```
include(../common/linux_device_pre.conf)

QMAKE_RPATHLINKDIR_POST += $$[QT_SYSROOT]/opt/vc/lib

VC_LIBRARY_PATH         = /opt/vc/lib
VC_INCLUDE_PATH         = =/opt/vc/include

VC_LINK_LINE            = -L=$${VC_LIBRARY_PATH}

QMAKE_LIBDIR_OPENGL_ES2 = =$${VC_LIBRARY_PATH}
QMAKE_LIBDIR_EGL        = $$QMAKE_LIBDIR_OPENGL_ES2
QMAKE_LIBDIR_OPENVG     = $$QMAKE_LIBDIR_OPENGL_ES2

QMAKE_INCDIR_EGL        = \
                        $${VC_INCLUDE_PATH} \
                        $${VC_INCLUDE_PATH}/interface/vcos/pthreads \
                        $${VC_INCLUDE_PATH}/interface/vmcs_host/linux

QMAKE_INCDIR_OPENGL_ES2 = $${QMAKE_INCDIR_EGL}

QMAKE_LIBS_OPENGL_ES2   = $${VC_LINK_LINE} -lGLESv2

# The official opt vc EGL references GLESv2 symbols: need to link it
QMAKE_LIBS_EGL          = $${VC_LINK_LINE} -lEGL -lGLESv2

QMAKE_LIBDIR_BCM_HOST   = =$$VC_LIBRARY_PATH
QMAKE_INCDIR_BCM_HOST   = $$VC_INCLUDE_PATH
QMAKE_LIBS_BCM_HOST     = -lbcm_host

QMAKE_CFLAGS            = -march=armv8-a -mtune=cortex-a53 #-mfpu=crypto-neon-fp-armv8 -std=c++11
QMAKE_CXXFLAGS          = $$QMAKE_CFLAGS

#DISTRO_OPTS            += hard-float
DISTRO_OPTS            += deb-multi-arch

EGLFS_DEVICE_INTEGRATION= eglfs_brcm

include(../common/linux_arm_device_post.conf)

load(qt_config)
```

_FILE_OFFSET_BITS=64

### 6. **Build Qt**

Once configured, you can build Qt for the Raspberry Pi:

```bash
make -j$(nproc)
```

This will take a while, depending on the power of your host machine.

### 7. **Install Qt**

After the build process is complete, install the cross-compiled Qt libraries to a local directory:

```bash
sudo make install
```

You can specify an installation path with the `-prefix` option in the `./configure` command (e.g., `/opt/qt5.15`).

### 8. **Deploying to Raspberry Pi**

Once the build is complete, transfer the Qt libraries, headers, and binaries to your Raspberry Pi. Use `scp` or an external drive to copy the files.

```bash
scp -r /opt/qt5.15 pi@raspberrypi:/opt/
```

Ensure that the libraries and headers are correctly installed on the Pi.

### 9. **Setting up Environment on Raspberry Pi**

To use the cross-compiled Qt libraries on the Raspberry Pi, you'll need to set the environment variables for Qt.

```bash
export QT_QPA_PLATFORM=linuxfb
export QTDIR=/opt/qt5.15
export PATH=$QTDIR/bin:$PATH
export LD_LIBRARY_PATH=$QTDIR/lib:$LD_LIBRARY_PATH
```

Add these lines to your `~/.bashrc` on the Raspberry Pi to make them persistent.

### 10. **Test Your Qt Application**

Finally, you can test your Qt applications on the Raspberry Pi. If you've cross-compiled everything successfully, your Qt apps should work on the Pi without issues.

### 11. **Optional: Emulate on the Host**

You can use **QEMU** to emulate a Raspberry Pi environment on your host machine and test your Qt applications before deploying them to the physical device.

```bash
qemu-arm-static ./your-qt-app
```

This allows you to run ARM binaries on your x86 machine (though performance will be slower than running on actual hardware).

### Conclusion

This guide covers the steps to cross-compile Qt 5.15 for the Raspberry Pi 3+. The process involves setting up the cross-compiler, configuring Qt for the Raspberry Pi, building and installing the libraries, and finally deploying them to the Pi. Once set up, you'll be able to run and develop Qt applications on your Raspberry Pi more efficiently.
