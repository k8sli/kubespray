#!/bin/bash
GREEN_COL="\\033[32;1m"
RED_COL="\\033[1;31m"
NORMAL_COL="\\033[0;39m"

INPUT=$1
SOURCE_REGISTRY=$2

: ${INPUT:=build}
: ${IMAGE_ARCH:="amd64"}
: ${IMAGES_DIR:="images"}
: ${IMAGES_LIST_DIR:="."}
: ${SOURCE_REGISTRY:="upstream"}
: ${SOURCE_IMAGES_YAML:="images_origin.yaml"}

BLOBS_PATH="docker/registry/v2/blobs/sha256"
REPO_PATH="docker/registry/v2/repositories"

set -eo pipefail

CURRENT_NUM=0
IMAGES="$(sed -n '/#/d;s/:/:/p' ${IMAGES_LIST_DIR}/images_${IMAGE_ARCH}*.list | grep -E '^library' | sort -u)"
TOTAL_NUMS=$(echo "${IMAGES}" | wc -l | tr -d ' ')

skopeo_copy(){
    if skopeo copy --insecure-policy --src-tls-verify=false --dest-tls-verify=false \
    --override-arch ${IMAGE_ARCH} --override-os linux -q docker://$1 dir:$2; then
        echo -e "$GREEN_COL Progress: ${CURRENT_NUM}/${TOTAL_NUMS} sync $1 to $2 successful $NORMAL_COL"
    else
        echo -e "$RED_COL Progress: ${CURRENT_NUM}/${TOTAL_NUMS} sync $1 to $2 failed $NORMAL_COL"
        exit 2
    fi
}

main(){
    rm -rf ${IMAGES_DIR}; mkdir -p ${IMAGES_DIR}
    for image in ${IMAGES}; do
        let CURRENT_NUM=${CURRENT_NUM}+1
        local image_name=${image%%:*}
        local image_tag=${image##*:}
        local image_repo=${image%%/*}
        mkdir -p ${IMAGES_DIR}/${image_repo}
        if [[ "${SOURCE_REGISTRY}" == "upstream" ]]; then
            local origin_image=$(yq eval '.[]|select(.dest=="'"${image_name}"'") | .src' ${SOURCE_IMAGES_YAML})
            skopeo_copy ${origin_image}:${image_tag} ${IMAGES_DIR}/${image}
        else
            skopeo_copy ${SOURCE_REGISTRY}/${image} ${IMAGES_DIR}/${image}
        fi

        manifest="${IMAGES_DIR}/${image}/manifest.json"
        manifest_sha256=$(sha256sum ${manifest} | awk '{print $1}')
        mkdir -p ${BLOBS_PATH}/${manifest_sha256:0:2}/${manifest_sha256}
        ln -f ${manifest} ${BLOBS_PATH}/${manifest_sha256:0:2}/${manifest_sha256}/data

        # make image repositories dir
        mkdir -p ${REPO_PATH}/${image_name}/{_uploads,_layers,_manifests}
        mkdir -p ${REPO_PATH}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}
        mkdir -p ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/{current,index/sha256}
        mkdir -p ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}

        # create image tag manifest link file
        echo -n "sha256:${manifest_sha256}" > ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/current/link
        echo -n "sha256:${manifest_sha256}" > ${REPO_PATH}/${image_name}/_manifests/revisions/sha256/${manifest_sha256}/link
        echo -n "sha256:${manifest_sha256}" > ${REPO_PATH}/${image_name}/_manifests/tags/${image_tag}/index/sha256/${manifest_sha256}/link

        # link image layers file to registry blobs dir
        for layer in $(sed '/v1Compatibility/d' ${manifest} | grep -Eo "\b[a-f0-9]{64}\b"); do
            mkdir -p ${BLOBS_PATH}/${layer:0:2}/${layer}
            mkdir -p ${REPO_PATH}/${image_name}/_layers/sha256/${layer}
            echo -n "sha256:${layer}" > ${REPO_PATH}/${image_name}/_layers/sha256/${layer}/link
            ln -f ${IMAGES_DIR}/${image}/${layer} ${BLOBS_PATH}/${layer:0:2}/${layer}/data
        done
    done
}

main "$@"
