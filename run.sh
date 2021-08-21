#!/bin/bash
TYPE=$1
NODES_NAME=$2

KUBE_ROOT="$(cd "$(dirname "$0")" && pwd)"

: ${TYPE:="deploy-cluster"}
: ${ANSIBLE_FORKS:=10}
: ${BECOME_USER:="root"}
: ${INVENTORY:=${KUBE_ROOT}/config/inventory}
: ${ENV_FILE:=${KUBE_ROOT}/config/env.yml}
: ${INSTALL_STEPS_FILE:=${KUBE_ROOT}/config/.install_steps}

ANSIBLE_ARGS="-f ${ANSIBLE_FORKS} --become --become-user=root -i ${INVENTORY} -e @${ENV_FILE}"

#
# Set logging colors
#

NORMAL_COL=$(tput sgr0)
RED_COL=$(tput setaf 1)
WHITE_COL=$(tput setaf 7)
GREEN_COL=$(tput setaf 76)
YELLOW_COL=$(tput setaf 202)

debuglog(){ printf "${WHITE_COL}%s${NORMAL_COL}\n" "$@"; }
infolog(){ printf "${GREEN_COL}✔ %s${NORMAL_COL}\n" "$@"; }
warnlog(){ printf "${YELLOW_COL}➜ %s${NORMAL_COL}\n" "$@"; }
errorlog(){ printf "${RED_COL}✖ %s${NORMAL_COL}\n" "$@"; }

set -eo pipefail

if [[ ! -f ${INVENTORY} ]];then
  errorlog "${INVENTORY} file is missing, please check the inventory file is exists"
  exit 1
fi

deploy_cluster(){
  touch ${INSTALL_STEPS_FILE}
  STEPS="00-default-ssh-config 01-cluster-bootstrap-os 02-cluster-etcd 03-cluster-kubernetes 04-cluster-network 05-cluster-apps"
  for step in ${STEPS}; do
    if ! grep -q "${step}" ${INSTALL_STEPS_FILE}; then
      infolog "######  start deploy ${step}  ######"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/playbooks/${step}.yml; then
        echo ${step} >> ${INSTALL_STEPS_FILE}
        infolog "######  ${step} successfully installed  ######"
      else
        errorlog "######  ${step} installation failed  ######"
        exit 1
      fi
    else
      warnlog "######  ${step} is already installed, so skipped...  ######"
    fi
  done
}

main(){
  case $TYPE in
    deploy-cluster)
      infolog "######  start deploy kubernetes cluster  ######"
      deploy_cluster
      infolog "######  kubernetes cluster successfully installed  ######"
      ;;
    remove-cluster)
      infolog "######  start remove kubernetes cluster  ######"
      if ansible-playbook ${ANSIBLE_ARGS} ${KUBE_ROOT}/reset.yml >/dev/stdout 2>/dev/stderr; then
        rm -f ${INSTALL_STEP_FILE}
        infolog "######  kubernetes cluster successfully removed ######"
      fi
      ;;
    add-node)
      check_nodename_exist
      infolog "######  start add worker to kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} --limit="$NODES_NAME" ${KUBE_ROOT}/playbooks/10-scale-nodes.yml >/dev/stdout 2>/dev/stderr
      ;;
    remove-node)
      check_nodename_exist
      infolog "######  start remove worker from kubernetes cluster  ######"
      ansible-playbook ${ANSIBLE_ARGS} -e node="$NODES_NAME" -e reset_nodes=true ${KUBE_ROOT}/remove-node.yml >/dev/stdout 2>/dev/stderr
      ;;
    *)
      errorlog "unknow [TYPE] parameter: ${TYPE}"
      ;;
  esac
}

main "$@"
