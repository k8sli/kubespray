# It's necessary to set this because some environments don't link sh -> bash.
export SHELL := /bin/bash

# It's necessary to set the errexit flags for the bash shell.
export SHELLOPTS := errexit

REGISTRY                   ?= ghcr.io
IMAGE_REPO                 ?= $(REGISTRY)/k8sli
IMAGE_ARCH                 ?= amd64
ANSIBLE_ARCHITECTURE       ?= x86_64
IMAGES_LIST_DIR            ?= ./build/kubespray-images
FILES_LIST_DIR             ?= ./build/kubespray-files
BASE_IMAGE_VERSION         ?= latest
KUBESPRAY_BASE_IMAGE       ?= $(IMAGE_REPO)/kubespray-base:$(BASE_IMAGE_VERSION)

# All targets.
.PHONY: lint run list

lint:
	@bash hack/lint/lint.sh

# Run kubespray container in local machine for debug and test
run:
	docker run --rm -it --net=host -v $(shell pwd):/kubespray $(KUBESPRAY_BASE_IMAGE) bash

# Generate files and images list for build offline install package
list:
	@mkdir -p $(IMAGES_LIST_DIR) $(FILES_LIST_DIR)
	@IMAGE_ARCH=$(IMAGE_ARCH) ANSIBLE_ARCHITECTURE=$(ANSIBLE_ARCHITECTURE) bash build/generate.sh
	@bash /tmp/generate.sh | sed -n 's#^localhost/##p' | sort -u | tee $(IMAGES_LIST_DIR)/images_$(IMAGE_ARCH).list
	@bash /tmp/generate.sh | grep 'https://' | sort -u | tee ${FILES_LIST_DIR}/files_$(IMAGE_ARCH).list

.PHONY: mitogen clean
mitogen:
	ansible-playbook -c local mitogen.yml -vv
clean:
	rm -rf dist/
	rm *.retry
