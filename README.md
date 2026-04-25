# Qt cross-compilation for ARM

Docker images for use in the build stage of **CI/CD** pipelines targeting **ARM** architecture.

### Requirements

- Docker version `27.5.1`
- Docker buildx version `v0.20.0`

### Build docker image

To build the image run the command below:

```
docker build . -t <your-image-tag> -f <qt-version>-<architecture>.Dockerfile
```

Example:

```
docker build . -t qt5.15.2-aarch64 -f Qt5.15.2-aarch64.Dockerfile
```
