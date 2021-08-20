FROM alpine:3.12 as images
ARG SKOPEO_VERSION=v1.4.0
ARG YQ_VERSION=v4.11.2
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && apk --no-cache add bash wget ca-certificates \
    && wget -q -k https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH} -O /usr/local/bin/yq \
    && wget -q -k https://github.com/k8sli/skopeo/releases/download/${SKOPEO_VERSION}/skopeo-linux-${ARCH} -O /usr/local/bin/skopeo \
    && chmod a+x /usr/local/bin/*

WORKDIR /build
COPY build/kubespray-images/*  /build/
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && IMAGE_ARCH=${ARCH} bash build.sh 

FROM scratch
COPY --from=images /build/docker /docker
