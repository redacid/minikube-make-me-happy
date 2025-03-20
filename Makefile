-include .env
export
SHELL := /bin/bash
#DEBUG := --debug
#VERBOSE := --verbose

MINIKUBE_KUBERNETES_VERSION ?= 1.32.0
MINIKUBE_NODES ?= 1
MINIKUBE_MEMORY ?= 4G
MINIKUBE_CPUS ?= 4
MINIKUBE_DOMAIN_NAMES ?= minikube local.domain

# colors
GREEN = $(shell tput -Txterm setaf 2)
YELLOW = $(shell tput -Txterm setaf 3)
WHITE = $(shell tput -Txterm setaf 7)
RESET = $(shell tput -Txterm sgr0)
GRAY = $(shell tput -Txterm setaf 6)
TARGET_MAX_CHAR_NUM = 30

.EXPORT_ALL_VARIABLES:

all: help

deploy-minikube: @minikube-first-start @minikube-enable-addons @update-resolver

destroy-minikube: @minikube-delete

@minikube-first-start:
	minikube start -p minikube-$(MINIKUBE_KUBERNETES_VERSION) --nodes=$(MINIKUBE_NODES) --memory=$(MINIKUBE_MEMORY) --cpus=$(MINIKUBE_CPUS) --kubernetes-version=$(MINIKUBE_KUBERNETES_VERSION)

@minikube-enable-addons:
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable ingress
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable ingress-dns
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable default-storageclass
	#minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable volumesnapshots
	#minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable csi-hostpath-driver
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable storage-provisioner
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons enable metrics-server
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) ip

@minikube-add-node:
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) node add

@minikube-delete-node:
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) node delete minikube-1.32.0-m02

@ingress-dns-wait:
	@until [ `kubectl get pods -n kube-system kube-ingress-dns-minikube -o jsonpath="{.status.phase}" 2>/dev/null || echo "None"` == "Running" ]; do echo "Waiting for ingerss DNS starts"; sleep 1; done

@disable-resolved:
	echo "Disable systemd-resolved..."
	sudo systemctl stop systemd-resolved.service || exit 0;
	sudo systemctl disable systemd-resolved.service || exit 0;

.ONESHELL:
@update-resolver:
	@if `minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) status > /dev/null`; then
		make @disable-resolved
		echo "Enable dnsmasq as NetworkManager extension..."
		sudo mkdir -p /etc/NetworkManager/dnsmasq.d/ || exit 0;
		make @ingress-dns-wait

		@$(foreach domain,$(MINIKUBE_DOMAIN_NAMES), echo "======= Add domain $(domain) to dnsmasq =======" \
		&& echo "server=/.$(domain)/$(shell kubectl get pod kube-ingress-dns-minikube --template '{{.status.podIP}}' -n kube-system || exit 1)" \
		| sudo tee /etc/NetworkManager/dnsmasq.d/$(domain).conf > /dev/null || exit;)

		printf "[main]\ndns=dnsmasq\n" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null
		sudo systemctl restart NetworkManager.service
		echo "Update resolv.conf..."
		sudo unlink /etc/resolv.conf || exit 0
		sleep 3
		echo "Add nameserver(dnsmasq) to resolv.conf"
		echo "nameserver $(shell sudo netstat -tulnp | grep dnsmasq | awk '{printf "%s",$$4}' | cut -d ":" -f1 | head -n 1)" \
		| sudo tee /etc/resolv.conf > /dev/null
	@else
		echo "MINIKUBE $(MINIKUBE_KUBERNETES_VERSION) NOT STARTED!!"
	@fi

@minikube-start:
	minikube start -p minikube-$(MINIKUBE_KUBERNETES_VERSION)

@minikube-stop:
	minikube stop -p minikube-$(MINIKUBE_KUBERNETES_VERSION)

@minikube-delete: @minikube-stop
	minikube delete -p minikube-$(MINIKUBE_KUBERNETES_VERSION)

@list-addons:
	minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) addons list

set-context:
	kubectl config get-contexts
	#kubectl config set current-context eks-mng-serg
	kubectl config set current-context minikube-$(MINIKUBE_KUBERNETES_VERSION)


## Shows help. | Help
help:
	@echo ''
	@echo 'Usage:'
	@echo ''
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-_]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
		    if (index(lastLine, "|") != 0) { \
				stage = substr(lastLine, index(lastLine, "|") + 1); \
				printf "\n ${GRAY}%s: \n\n", stage;  \
			} \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			if (index(lastLine, "|") != 0) { \
				helpMessage = substr(helpMessage, 0, index(helpMessage, "|")-1); \
			} \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
	@echo ''