#!/bin/bash

kubectl config get-contexts

DST_DIR=/home/user
CFG_DIR=${DST_DIR}/wf-minikube
NEW_CLUSTER_HOST="https://1.1.1.1:6443"
MINIKUBE_CONFIG=wf-kube-config
CLUSTER_NAME=minikube-cluster
CURRENT_DATE=$(date '+%Y_%m_%d_%H_%M_%S')

mkdir -p ${CFG_DIR}
mkdir -p ${DST_DIR}/.kube/backup

ssh wf kubectl config view --flatten > ${CFG_DIR}/${MINIKUBE_CONFIG}

yq eval "(.clusters[] | select(.name == \"${CLUSTER_NAME}\") | .cluster.server) = \"${NEW_CLUSTER_HOST}\"" -i ${CFG_DIR}/${MINIKUBE_CONFIG}

cp ${DST_DIR}/.kube/config ${DST_DIR}/.kube/backup/config.backup-${CURRENT_DATE}

KUBECONFIG=${DST_DIR}/.kube/config:${CFG_DIR}/${MINIKUBE_CONFIG} kubectl config view --flatten > ${CFG_DIR}/config-merged

mv ${CFG_DIR}/config-merged ${DST_DIR}/.kube/config
chmod 600 ${DST_DIR}/.kube/config

echo "-------------------------------------------------------------------"

kubectl config get-contexts

