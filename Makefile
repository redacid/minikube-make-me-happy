-include .env
export
SHELL := /bin/bash
#DEBUG := --debug
#VERBOSE := --verbose

MINIKUBE_KUBERNETES_VERSION := 1.32.0
MINIKUBE_NODES := 2
MINIKUBE_MEMORY := 4G
MINIKUBE_CPUS := 4

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

.ONESHELL:
@update-resolver:
		@if `minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) status > /dev/null`; then
			echo "Disable resolved..."
			sudo systemctl stop systemd-resolved.service || exit 0;
			sudo systemctl disable systemd-resolved.service || exit 0;
			sudo mkdir -p /etc/NetworkManager/dnsmasq.d/ || exit 0;
			echo "Enable dnsmasq as NetworkManager extension..."
			echo "server=/.minikube/$(shell kubectl get pod kube-ingress-dns-minikube --template '{{.status.podIP}}' -n kube-system || exit 1)" \
			| sudo tee /etc/NetworkManager/dnsmasq.d/minikube.conf > /dev/null
			printf "[main]\ndns=dnsmasq\n" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null
			sudo systemctl restart NetworkManager.service
			echo "Update resolv.conf..."
			sudo unlink /etc/resolv.conf || exit 0
			sleep 3
			echo "nameserver $(shell sudo netstat -tulnp | grep dnsmasq | awk '{printf "%s",$$4}' | cut -d ":" -f1 | head -n 1)" \
			| sudo tee /etc/resolv.conf > /dev/null
		@else
			echo "MINIKUBE $(MINIKUBE_KUBERNETES_VERSION) NOT RUNNED!!"
		@fi

@update-resolver_old:
		# This need for resolving names *.minikube, https://vw.minikube etc...
		sudo systemctl stop systemd-resolved.service
		sudo systemctl disable systemd-resolved.service
		KUBE_DNS_IP=$(shell kubectl get pod kube-ingress-dns-minikube --template '{{.status.podIP}}' -n kube-system || exit 1)
		#KUDE_DNS_IP=$(shell minikube -p minikube-$(MINIKUBE_KUBERNETES_VERSION) ip)
		sudo mkdir -p /etc/NetworkManager/dnsmasq.d/
		echo "server=/.minikube/$KUBE_DNS_IP" | sudo tee /etc/NetworkManager/dnsmasq.d/minikube.conf > /dev/null
		# edit /etc/NetworkManager/NetworkManager.conf
		# add dns=dnsmasq in [main] section
		# edit /etc/resolv.conf
		# change resolver to 127.0.1.1
		printf "[main]\ndns=dnsmasq\n" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf > /dev/null
		sudo systemctl restart NetworkManager.service
		sudo unlink /etc/resolv.conf || exit 0
		sleep 3
		DNSMASQ_LISTEN_ADDR=$(shell sudo netstat -tulnp | grep dnsmasq | awk '{printf("%s",$4)}' | cut -d ":" -f1 | head -n 1)
		echo "nameserver $DNSMASQ_LISTEN_ADDR" | sudo tee /etc/resolv.conf > /dev/null

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