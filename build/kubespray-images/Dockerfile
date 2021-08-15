ARG BASE_IMAGE=ghcr.io/muzi502/kubespray-base
ARG BASE_IMAGE_VERSION=master
FROM $BASE_IMAGE:$BASE_IMAGE_VERSION as images
WORKDIR /build
COPY build/kubespray-images/*  /build/
COPY --from=mikefarah/yq:4.11.2 /usr/bin/yq /usr/bin/yq
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && IMAGE_ARCH=${ARCH} bash build.sh 

FROM scratch
COPY --from=images /build/docker /docker
