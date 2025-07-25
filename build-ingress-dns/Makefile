-include .env
export
SHELL := /bin/bash

REGISTRY ?= docker.io
REGISTRY_USER ?= NEED-TO-BE-SET
REGISTRY_PASSWORD ?= NEED-TO-BE-SET

VERSION := $(shell jq -r '.version' app/dns-server/nodejs/package.json)
IMAGE := $(REGISTRY)/gitlabprozorro/minikube-ingress-dns

# colors
GREEN = $(shell tput -Txterm setaf 2)
YELLOW = $(shell tput -Txterm setaf 3)
WHITE = $(shell tput -Txterm setaf 7)
RESET = $(shell tput -Txterm sgr0)
GRAY = $(shell tput -Txterm setaf 6)
TARGET_MAX_CHAR_NUM = 30

.EXPORT_ALL_VARIABLES:

all: help

docker-login:
	@echo "$(REGISTRY_PASSWORD)" | docker login $(REGISTRY) --username "$(REGISTRY_USER)" --password-stdin

docker-build:
	docker build app/dns-server -f app/dns-server/Dockerfile --tag $(IMAGE):$(VERSION) --tag $(IMAGE):latest
	docker images

docker-push: docker-build docker-login
	docker push gitlabprozorro/minikube-ingress-dns:latest
	docker push gitlabprozorro/minikube-ingress-dns:$(VERSION)


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
