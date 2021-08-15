#!/bin/bash
set -eo pipefail

SCRIPT_PATH=$(cd $(dirname $0); pwd)
REPO_PATH="${SCRIPT_PATH%/hack/build}"

: ${IMAGE_ARCH:="amd64"}
: ${ANSIBLE_ARCHITECTURE:="x86_64"}
: ${DOWNLOAD_YML:="config/group_vars/all/download.yml"}

# ARCH used in convert {%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%} to {{arch}}
if [[ "${IMAGE_ARCH}" != "amd64" ]]; then ARCH="-${IMAGE_ARCH}"; fi

cat > /tmp/generate.sh << EOF
arch=${ARCH}
download_url=https:/
image_arch=${IMAGE_ARCH}
ansible_system=linux
ansible_architecture=${ANSIBLE_ARCHITECTURE}
registry_project=library
registry_domain=localhost
EOF

# generate all component version by $DOWNLOAD_YML
grep '_version:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> /tmp/generate.sh

# generate download files url list
grep '_download_url:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed 's/: /=/g;s/ //g;s/{{/${/g;s/}}/}/g;s/|lower//g;s/^.*_url=/echo /g' >> /tmp/generate.sh

# generate download images list
grep -E '_image_tag:|_image_repo:|_image_name:' ${REPO_PATH}/${DOWNLOAD_YML} \
| sed "s#{%- if image_arch != 'amd64' -%}-{{ image_arch }}{%- endif -%}#{{arch}}#g" \
| sed 's/: /=/g;s/{{/${/g;s/}}/}/g' | tr -d ' ' >> /tmp/generate.sh

grep '_image_name:' ${REPO_PATH}/${DOWNLOAD_YML} \
| cut -d ':' -f1 | sed 's/^/echo $/g' >> /tmp/generate.sh
