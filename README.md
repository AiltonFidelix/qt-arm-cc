# Qt cross-compilation for ARM

Docker images for use in the build stage of **CI/CD** pipelines targeting **ARM** architectures.

### Requirements

- Docker version `27.5.1`
- Docker buildx version `v0.20.0`

### TODO

- Implement openssl support on **Qt5.15.2-armhf32** image

### Build docker image

To build the image run the command below:

```
docker build . -t <your-image-tag> -f Dockerfile.<qt-version>-<architecture> 
```

Example:

```
docker build . -t qt5.15.2-aarch64 -f Dockerfile.Qt5.15.2-aarch64
```

**Note**: As stated in the `TODO` section, version `Qt5.15.2-armhf32` does not yet implement openssl support.

---

Created by `Ailton Fidelix`

[![Linkedin Badge](https://img.shields.io/badge/-Ailton-blue?style=flat-square&logo=Linkedin&logoColor=white&link=https://www.linkedin.com/in/ailtonfidelix/)](https://www.linkedin.com/in/ailton-fidelix-9603b31b7/) 