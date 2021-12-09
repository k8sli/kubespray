FROM python:3 as builder
ARG KUBE_VERSION=v1.21.3
COPY . .
RUN echo 'shellcheck-py==0.7.2.1' >> requirements.txt \
    && grep -E '^yamllint|^ansible-lint' tests/requirements.txt >> requirements.txt \
    && pip3 install --user -r requirements.txt

RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') \
    && wget -O /root/.local/bin/kubectl -q https://dl.k8s.io/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl \
	&& chmod a+x /root/.local/bin/kubectl

FROM python:3-slim
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y -qq \
    && apt-get install -y -qq --no-install-recommends \
        ca-certificates libssl-dev openssh-client sshpass curl gnupg2 rsync \
        jq moreutils vim iputils-ping wget tcpdump xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /usr/local
WORKDIR /kubespray
