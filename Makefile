-include .env
export
SHELL := /bin/bash
#DEBUG := --debug
#VERBOSE := --verbose

MINIKUBE_KUBERNETES_VERSION ?= 1.32.0
MINIKUBE_NODES ?= 2
MINIKUBE_MEMORY ?= 2G
MINIKUBE_CPUS ?= 4
MINIKUBE_DOMAIN_NAMES ?= minikube local.domain
MINIKUBE_CONTEXT := minikube-$(MINIKUBE_KUBERNETES_VERSION)
MINIKUBE_SA_NAME := redacid

# colors
GREEN = $(shell tput -Txterm setaf 2)
YELLOW = $(shell tput -Txterm setaf 3)
WHITE = $(shell tput -Txterm setaf 7)
RESET = $(shell tput -Txterm sgr0)
GRAY = $(shell tput -Txterm setaf 6)
TARGET_MAX_CHAR_NUM = 30

.EXPORT_ALL_VARIABLES:

all: help

## First start minikube cluster
minikube-deploy: @minikube-first-start @minikube-enable-addons @update-resolver

## Start stopped minikube cluster
minikube-start:
	minikube start -p $(MINIKUBE_CONTEXT)

## Stop minikube cluster
minikube-stop:
	minikube stop -p $(MINIKUBE_CONTEXT)

## Destroy minikube cluster
minikube-destroy: @minikube-delete

minikube-add-node:
	minikube -p $(MINIKUBE_CONTEXT) node add

minikube-delete-last-node:
	minikube -p $(MINIKUBE_CONTEXT) node delete $(shell minikube -p $(MINIKUBE_CONTEXT) node list | egrep "$(MINIKUBE_CONTEXT)-m[0-9]" | awk '{printf("%s\n",$$1)}' | sort -r | head -n 1)

create-service-account:
	make @check_current_context
	kubectl create serviceaccount $(MINIKUBE_SA_NAME) -n kube-system
	kubectl create clusterrolebinding $(MINIKUBE_SA_NAME)-cluster-admin-crb  --clusterrole=cluster-admin --serviceaccount=kube-system:$(MINIKUBE_SA_NAME)
	kubectl create token $(MINIKUBE_SA_NAME) -n kube-system > sa-token.txt

curl-api:
	make @check_current_context
	@curl $(shell kubectl config view --minify --output jsonpath="{.clusters[*].cluster.server}")/apis/networking.k8s.io/v1/ingresses --silent \
         --header "Authorization: Bearer $(shell cat sa-token.txt)" --insecure

## Install kubectl
install-kubectl:
	sudo curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl --output /usr/bin/kubectl"
	sudo chmod +x /usr/bin/kubectl

## Install minikube binary
install-minikube:
	sudo curl -L https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 --output /usr/bin/minikube
	sudo chmod +x /usr/bin/minikube

#### DON'T TOUCH BOTTOM TARGETS, USE ONLY AHEAD )))

# original https://console.cloud.google.com/artifacts/docker/k8s-minikube/us/gcr.io/minikube-ingress-dns?inv=1&invt=AbsmyA
# https://github.com/kubernetes/minikube/tree/master/deploy/addons/ingress-dns
# https://gitlab.com/cryptexlabs/public/development/minikube-ingress-dns
# patched https://hub.docker.com/repository/docker/gitlabprozorro/minikube-ingress-dns/tags

@deploy-patched-ingress-dns:
	kubectl apply -f minikube-ingress-dns.yaml

@minikube-first-start:
	minikube start -p $(MINIKUBE_CONTEXT) \
		--nodes=$(MINIKUBE_NODES) \
		--memory=$(MINIKUBE_MEMORY) \
		--cpus=$(MINIKUBE_CPUS) \
		--kubernetes-version=$(MINIKUBE_KUBERNETES_VERSION) \
		--cni calico

@minikube-enable-addons:
	minikube -p $(MINIKUBE_CONTEXT) addons enable ingress
	make @check_current_context
	make @deploy-patched-ingress-dns
	#minikube -p $(MINIKUBE_CONTEXT) addons enable ingress-dns
	minikube -p $(MINIKUBE_CONTEXT) addons enable metrics-server
	minikube -p $(MINIKUBE_CONTEXT) addons enable default-storageclass
	minikube -p $(MINIKUBE_CONTEXT) addons enable volumesnapshots
	minikube -p $(MINIKUBE_CONTEXT) addons enable csi-hostpath-driver
	minikube -p $(MINIKUBE_CONTEXT) addons enable storage-provisioner
	minikube -p $(MINIKUBE_CONTEXT) ip

@check_current_context:
	@until [ `kubectl config current-context 2>/dev/null || echo "None"` == "$(MINIKUBE_CONTEXT)" ]; do echo "Current context not $(MINIKUBE_CONTEXT)"; sleep 1; done

@ingress-dns-wait:
	@make @check_current_context
	@until [ `kubectl get pods -n kube-system kube-ingress-dns-minikube -o jsonpath="{.status.phase}" 2>/dev/null || echo "None"` == "Running" ]; do echo "Waiting for ingerss DNS starts"; sleep 1; done

@disable-resolved:
	echo "Disable systemd-resolved..."
	sudo systemctl stop systemd-resolved.service || exit 0;
	sudo systemctl disable systemd-resolved.service || exit 0;

.ONESHELL:
@update-resolver:
	@if `minikube -p $(MINIKUBE_CONTEXT) status > /dev/null`; then
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
		echo "MINIKUBE $(MINIKUBE_CONTEXT) NOT STARTED!!"
	@fi

@minikube-delete: minikube-stop
	minikube delete -p $(MINIKUBE_CONTEXT)

@list-addons:
	minikube -p $(MINIKUBE_CONTEXT) addons list

@set-context:
	kubectl config get-contexts
	kubectl config set current-context $(MINIKUBE_CONTEXT)

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