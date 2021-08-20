#!/bin/bash

GREEN_COL="\\033[32;1m"
RED_COL="\\033[1;31m"
YELLOW_COL="\\033[33;1m"
NORMAL_COL="\\033[0;39m"

LINT_PATH="."
ANSIBLE_VERBOSITY="3"
ANSIBLE_BECOME="true"
ANSIBLE_BECOME_USER="root"
ANSIBLE_REMOTE_USER="root"
ANSIBLE_INVENTORY="inventory/local/hosts.ini"

rm -f linterr.txt stderr.txt

yaml_lint() {
    yamllint --strict ${LINT_PATH} > stderr.txt
    if [ $? -ne 0 ] || [ -s stderr.txt ]; then
        cat stderr.txt >> linterr.txt
        echo "-----------------------------------------" >> linterr.txt
    fi
}

ansible_check() {
    for file in $(find playbooks -type f -name '*.yml'); do
        ansible-playbook -i ${ANSIBLE_INVENTORY} --syntax-check ${file} 2> stderr.txt
        if [ $? -ne 0 ] && [ -s stderr.txt ]; then
            echo $file >> linterr.txt
            cat stderr.txt >> linterr.txt
            echo "-----------------------------------------" >> linterr.txt
        fi
    done
}

shell_check() {
    for file in $(find ${LINT_PATH} -name '*.sh' -not -path './contrib/*'); do
        shellcheck --severity error ${file} > stderr.txt
        if [ $? -ne 0 ] || [ -s stderr.txt ]; then
            echo $file >> linterr.txt
            cat stderr.txt >> linterr.txt
            echo "-----------------------------------------" >> linterr.txt
        fi
    done
}

check_output() {
    if [ -s linterr.txt ]; then
        printf '\n'
        echo -e "$RED_COL Error lint, please check following files: $NORMAL_COL"
        echo -e "$RED_COL ----------------------------------------- $NORMAL_COL"
        cat linterr.txt
        echo -e "$RED_COL Repo lint failed. $NORMAL_COL"
        exit 1
    else
        echo -e "$GREEN_COL Successfully lint $NORMAL_COL"
        rm -f linterr.txt stderr.txt
    fi
}

yaml_lint || true
shell_check || true
ansible_check || true
check_output
