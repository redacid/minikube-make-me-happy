-include .env
export
SHELL := /bin/bash
#DEBUG := --debug
#VERBOSE := --verbose
YQ_PIPE = $(shell command -v yq 2>/dev/null | xargs -I {} sh -c '[ -x "{}" ] 2>/dev/null && echo "| {} "' )
MINIKUBE_KUBERNETES_VERSION ?= 1.33.0
MINIKUBE_NODES ?= 1
MINIKUBE_MEMORY ?= 4G
MINIKUBE_CPUS ?= 4
MINIKUBE_CONTEXT := minikube-cluster
MINIKUBE_SA_NAME := redacid
MINIKUBE_SA_TOKEN_DURATION := 87600h
MINIKUBE_API_SERVER := --apiserver-ips=127.0.0.1,$(EXTERNAL_SERVER_IP) --listen-address=0.0.0.0 --apiserver-port=8443

# colors
GREEN = $(shell tput -Txterm setaf 2)
YELLOW = $(shell tput -Txterm setaf 3)
WHITE = $(shell tput -Txterm setaf 7)
RESET = $(shell tput -Txterm sgr0)
GRAY = $(shell tput -Txterm setaf 6)
TARGET_MAX_CHAR_NUM = 30

.EXPORT_ALL_VARIABLES:

all: help

test_yq:
	cat minikube-ingress-dns.yaml $(YQ_PIPE)

## Minikube version
minikube-version:
	minikube version

## First start minikube cluster
minikube-deploy: @minikube-first-start @minikube-enable-addons

## Destroy minikube cluster
minikube-destroy: @minikube-delete

## Start stopped minikube cluster
minikube-start:
	minikube start $(MINIKUBE_API_SERVER) -p $(MINIKUBE_CONTEXT)

## Stop minikube cluster
minikube-stop:
	minikube stop -p $(MINIKUBE_CONTEXT)

minikube-add-node:
	minikube -p $(MINIKUBE_CONTEXT) node add

minikube-delete-last-node:
	minikube -p $(MINIKUBE_CONTEXT) node delete $(shell minikube -p $(MINIKUBE_CONTEXT) node list | egrep "$(MINIKUBE_CONTEXT)-m[0-9]" | awk '{printf("%s\n",$$1)}' | sort -r | head -n 1)

create-service-account:
	make @check_current_context
	kubectl create serviceaccount $(MINIKUBE_SA_NAME) -n kube-system
	kubectl create clusterrolebinding $(MINIKUBE_SA_NAME)-cluster-admin-crb  --clusterrole=cluster-admin --serviceaccount=kube-system:$(MINIKUBE_SA_NAME)
	kubectl create token $(MINIKUBE_SA_NAME) --duration=$(MINIKUBE_SA_TOKEN_DURATION) -n kube-system > sa-token.txt

curl-api:
	make @check_current_context
	@curl $(shell kubectl config view --minify --output jsonpath="{.clusters[*].cluster.server}")/apis/networking.k8s.io/v1/ingresses --silent \
         --header "Authorization: Bearer $(shell cat sa-token.txt)" --insecure

## Install kubectl
install-kubectl:
	sudo curl -L "https://dl.k8s.io/release/$(shell curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" --output /usr/local/bin/kubectl
	sudo chmod +x /usr/local/bin/kubectl

## Install minikube binary
install-minikube:
	sudo curl -L https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 --output /usr/local/bin/minikube
	sudo chmod +x /usr/local/bin/minikube

#### DON'T TOUCH BOTTOM TARGETS, USE ONLY AHEAD )))

# original https://console.cloud.google.com/artifacts/docker/k8s-minikube/us/gcr.io/minikube-ingress-dns?inv=1&invt=AbsmyA
# https://github.com/kubernetes/minikube/tree/master/deploy/addons/ingress-dns
# https://gitlab.com/cryptexlabs/public/development/minikube-ingress-dns
# patched https://hub.docker.com/repository/docker/gitlabprozorro/minikube-ingress-dns/tags

@deploy-patched-ingress-dns:
	kubectl apply -f minikube-ingress-dns.yaml

@minikube-first-start:
	minikube start $(MINIKUBE_API_SERVER) -p $(MINIKUBE_CONTEXT) \
		--nodes=$(MINIKUBE_NODES) \
		--memory=$(MINIKUBE_MEMORY) \
		--cpus=$(MINIKUBE_CPUS) \
		--kubernetes-version=$(MINIKUBE_KUBERNETES_VERSION) \
		--cni calico

@minikube-enable-addons:
	#minikube -p $(MINIKUBE_CONTEXT) addons enable ingress
	make @check_current_context
	make @deploy-patched-ingress-dns
	#minikube -p $(MINIKUBE_CONTEXT) addons enable ingress-dns
	minikube -p $(MINIKUBE_CONTEXT) addons enable metrics-server
	minikube -p $(MINIKUBE_CONTEXT) addons enable default-storageclass
	minikube -p $(MINIKUBE_CONTEXT) addons enable volumesnapshots
	minikube -p $(MINIKUBE_CONTEXT) addons enable csi-hostpath-driver
	minikube -p $(MINIKUBE_CONTEXT) addons enable storage-provisioner
	minikube -p $(MINIKUBE_CONTEXT) ip

create-retain-sc: @check_current_context
	kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
	kubectl apply -f ./storage-classes-retain.yaml

@check_current_context:
	@until [ `kubectl config current-context 2>/dev/null || echo "None"` == "$(MINIKUBE_CONTEXT)" ]; do echo "Current context not $(MINIKUBE_CONTEXT)"; sleep 1; done

@ingress-dns-wait:
	@make @check_current_context
	@until [ `kubectl get pods -n kube-system kube-ingress-dns-minikube -o jsonpath="{.status.phase}" 2>/dev/null || echo "None"` == "Running" ]; do echo "Waiting for ingerss DNS starts"; sleep 1; done

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