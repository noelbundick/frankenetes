#!/bin/bash

############
# Azure setup
############

AZURE_RESOURCE_GROUP=$1
# AZURE_STORAGE_ACCOUNT needs to be an environment var for Azure CLI
export AZURE_STORAGE_ACCOUNT=$2
ETCD_DNS_LABEL=$3
APISERVER_DNS_LABEL=$4

REGION=eastus
ETCD_FQDN="$ETCD_DNS_LABEL.$REGION.azurecontainer.io"
APISERVER_FQDN="$APISERVER_DNS_LABEL.$REGION.azurecontainer.io"

OUTPUT_DIR=output

az group create -n $AZURE_RESOURCE_GROUP -l $REGION
az storage account create -n $AZURE_STORAGE_ACCOUNT -g $AZURE_RESOURCE_GROUP --sku Standard_LRS

AZURE_STORAGE_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $AZURE_RESOURCE_GROUP --query '[0].value' -o tsv)

############
# generate certs
############

# Create a share for TLS data
az storage share create -n tls
az storage file upload-batch -s ./tls -d tls --max-connections 5

# Generate certs with a container instance
az container create -g $AZURE_RESOURCE_GROUP \
  --name cfssl \
  --image cfssl/cfssl \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name tls \
  --azure-file-volume-mount-path /kube-tls \
  --command-line "/bin/sh -c '/kube-tls/create_certs.sh $ETCD_FQDN $APISERVER_FQDN'" \
  --restart-policy Never

# Synchronously wait until the container is finished
az container attach -n cfssl -g $AZURE_RESOURCE_GROUP

# Clean up
az container delete -n cfssl -g $AZURE_RESOURCE_GROUP -y

# Download generated certs/keys
mkdir -p $OUTPUT_DIR
az storage file download-batch -s tls -d $OUTPUT_DIR --pattern '*.pem' --max-connections 5

############
# create admin kubeconfig
############
ADMIN_KUBECONFIG=$OUTPUT_DIR/admin.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=./$OUTPUT_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$ADMIN_KUBECONFIG
kubectl config set-credentials admin \
  --client-certificate=./$OUTPUT_DIR/admin.pem \
  --client-key=./$OUTPUT_DIR/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=$ADMIN_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=admin \
  --kubeconfig=$ADMIN_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$ADMIN_KUBECONFIG

echo "admin kubeconfig created at $ADMIN_KUBECONFIG"

############
# create controller manager kubeconfig
############
CONTROLLER_MANAGER_KUBECONFIG=$OUTPUT_DIR/controller-manager.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=./$OUTPUT_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config set-credentials controller-manager \
  --client-certificate=./$OUTPUT_DIR/kube-controller-manager.pem \
  --client-key=./$OUTPUT_DIR/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=controller-manager \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG

echo "controller manager kubeconfig created at $CONTROLLER_MANAGER_KUBECONFIG"

############
# create scheduler kubeconfig
############
SCHEDULER_KUBECONFIG=$OUTPUT_DIR/scheduler.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=./$OUTPUT_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config set-credentials scheduler \
  --client-certificate=./$OUTPUT_DIR/kube-scheduler.pem \
  --client-key=./$OUTPUT_DIR/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=scheduler \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$SCHEDULER_KUBECONFIG

echo "scheduler kubeconfig created at $SCHEDULER_KUBECONFIG"

############
# create virtual-kubelet kubeconfig
############
VK_KUBECONFIG=$OUTPUT_DIR/virtual-kubelet.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=./$OUTPUT_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$VK_KUBECONFIG
kubectl config set-credentials system:node:virtual-kubelet \
  --client-certificate=./$OUTPUT_DIR/virtual-kubelet.pem \
  --client-key=./$OUTPUT_DIR/virtual-kubelet-key.pem \
  --embed-certs=true \
  --kubeconfig=$VK_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=system:node:virtual-kubelet \
  --kubeconfig=$VK_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$VK_KUBECONFIG

echo "virtual-kubelet kubeconfig created at $VK_KUBECONFIG"

############
# create virtual-kubelet-win kubeconfig
############
VK_WIN_KUBECONFIG=$OUTPUT_DIR/virtual-kubelet-win.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=./$OUTPUT_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config set-credentials system:node:virtual-kubelet-win \
  --client-certificate=./$OUTPUT_DIR/virtual-kubelet-win.pem \
  --client-key=./$OUTPUT_DIR/virtual-kubelet-win-key.pem \
  --embed-certs=true \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=system:node:virtual-kubelet-win \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$VK_WIN_KUBECONFIG

echo "virtual-kubelet-win kubeconfig created at $VK_WIN_KUBECONFIG"

############
# etcd
############

# Create an Azure File share to hold cluster data
az storage share create -n etcd

# Upload certs for secure communication
az storage directory create -s etcd -n certs
az storage file upload -s etcd --source $OUTPUT_DIR/etcd.pem -p certs/etcd.pem
az storage file upload -s etcd --source $OUTPUT_DIR/etcd-key.pem -p certs/etcd-key.pem
az storage file upload -s etcd --source $OUTPUT_DIR/ca.pem -p certs/ca.pem

#WARNING! This isn't useful until I fix the write ahead log
#TODO: figure out why I get "create wal error: rename /etcd/data/member/wal.tmp /etcd/data/member/wal: permission denied" when --wal-dir is not set
#TODO: 3.3 errors out with "etcdserver: publish error: etcdserver: request timed out"
az container create -g $AZURE_RESOURCE_GROUP \
  --name etcd \
  --image quay.io/coreos/etcd:v3.2.8 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name etcd \
  --azure-file-volume-mount-path /etcd \
  --ports 2379 2380 \
  --ip-address public \
  --dns-name-label $ETCD_DNS_LABEL \
  --command-line "/usr/local/bin/etcd --name=frankenetes-etcd-0 --cert-file=/etcd/certs/etcd.pem --key-file=/etcd/certs/etcd-key.pem --trusted-ca-file=/etcd/certs/ca.pem --client-cert-auth --listen-client-urls=https://0.0.0.0:2379 --advertise-client-urls=https://$ETCD_FQDN:2379 --data-dir=/etcd/data --wal-dir=/etcd-wal"

############
# apiserver
############

# Create a share to hold certs/logs/etc
az storage share create -n apiserver

# Upload certs for secure communication
az storage directory create -s apiserver -n certs
az storage file upload -s apiserver --source $OUTPUT_DIR/kubernetes.pem -p certs/kubernetes.pem
az storage file upload -s apiserver --source $OUTPUT_DIR/kubernetes-key.pem -p certs/kubernetes-key.pem
az storage file upload -s apiserver --source $OUTPUT_DIR/etcd.pem -p certs/etcd.pem
az storage file upload -s apiserver --source $OUTPUT_DIR/etcd-key.pem -p certs/etcd-key.pem
az storage file upload -s apiserver --source $OUTPUT_DIR/ca.pem -p certs/ca.pem
az storage file upload -s apiserver --source $OUTPUT_DIR/ca-key.pem -p certs/ca-key.pem

az container create -g $AZURE_RESOURCE_GROUP \
  --name apiserver \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name apiserver \
  --azure-file-volume-mount-path /apisrv \
  --ports 6443 \
  --ip-address public \
  --dns-name-label $APISERVER_DNS_LABEL \
  --command-line "/apiserver --admission-control=NamespaceLifecycle,LimitRanger,ResourceQuota --advertise-address=0.0.0.0 --allow-privileged=true --apiserver-count=1 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/apisrv/log/audit.log --authorization-mode=Node,RBAC --bind-address=0.0.0.0 --client-ca-file=/apisrv/certs/ca.pem --enable-swagger-ui=true --etcd-cafile=/apisrv/certs/ca.pem --etcd-certfile=/apisrv/certs/etcd.pem --etcd-keyfile=/apisrv/certs/etcd-key.pem --etcd-servers=https://$ETCD_FQDN:2379 --event-ttl=1h --insecure-bind-address=127.0.0.1 --kubelet-certificate-authority=/apisrv/certs/ca.pem --kubelet-client-certificate=/apisrv/certs/kubernetes.pem --kubelet-client-key=/apisrv/certs/kubernetes-key.pem --kubelet-https=true --runtime-config=api/all --runtime-config=admissionregistration.k8s.io/v1alpha1 --service-account-key-file=/apisrv/certs/ca-key.pem --service-node-port-range=30000-32767 --tls-ca-file=/apisrv/certs/ca.pem --tls-cert-file=/apisrv/certs/kubernetes.pem --tls-private-key-file=/apisrv/certs/kubernetes-key.pem --v=2"
  
# --admission-control=Initializers,NodeRestriction,DefaultStorageClass,ServiceAccount
# --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \
# --service-cluster-ip-range=10.32.0.0/24 \

############
# controller manager
############

# Create a share to hold certs/logs/etc
az storage share create -n controllermanager
az storage directory create -s controllermanager -n certs
az storage file upload -s controllermanager --source $CONTROLLER_MANAGER_KUBECONFIG -p controller-manager.kubeconfig
az storage file upload -s controllermanager --source $OUTPUT_DIR/ca.pem -p certs/ca.pem
az storage file upload -s controllermanager --source $OUTPUT_DIR/ca-key.pem -p certs/ca-key.pem

az container create -g $AZURE_RESOURCE_GROUP \
  --name controllermanager \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name controllermanager \
  --azure-file-volume-mount-path /cm \
  --command-line "/controller-manager --address=0.0.0.0 --cluster-cidr=10.200.0.0/16 --cluster-name=kubernetes --cluster-signing-cert-file=/cm/certs/ca.pem --cluster-signing-key-file=/cm/certs/ca-key.pem --kubeconfig=/cm/controller-manager.kubeconfig --leader-elect=true --root-ca-file=/cm/certs/ca.pem --service-account-private-key-file=/cm/certs/ca-key.pem --use-service-account-credentials --v=2"

# --service-cluster-ip-range=10.32.0.0/24

############
# scheduler
############

# Create a share to hold certs/logs/etc
az storage share create -n scheduler
az storage file upload -s scheduler --source $SCHEDULER_KUBECONFIG -p scheduler.kubeconfig

az container create -g $AZURE_RESOURCE_GROUP \
  --name scheduler \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name scheduler \
  --azure-file-volume-mount-path /sched \
  --command-line "/scheduler --kubeconfig=/sched/scheduler.kubeconfig --leader-elect=true --v=2"

############
# defaults
############
export KUBECONFIG=$ADMIN_KUBECONFIG
kubectl apply -f ./defaults

############
# virtual-kubelet setup
############

# Create a share for virtual-kubelet configuration
az storage share create -n virtual-kubelet

# TODO: create an azure provider config file

# upload files
az storage file upload -s virtual-kubelet --source $VK_KUBECONFIG -p virtual-kubelet.kubeconfig
az storage file upload -s virtual-kubelet --source $VK_WIN_KUBECONFIG -p virtual-kubelet-win.kubeconfig
az storage file upload -s virtual-kubelet --source credentials.json

# Create a second resource group to hold pods
az group create -n "${AZURE_RESOURCE_GROUP}-pods" -l $REGION

############
# virtual-kubelet (linux)
############

az container create -g $AZURE_RESOURCE_GROUP \
  --name virtual-kubelet \
  --image microsoft/virtual-kubelet \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name virtual-kubelet \
  --azure-file-volume-mount-path /etc/virtual-kubelet \
  -e AZURE_AUTH_LOCATION=/etc/virtual-kubelet/credentials.json ACI_RESOURCE_GROUP=frankenetes-pods ACI_REGION=$REGION \
  --command-line "/usr/bin/virtual-kubelet --kubeconfig /etc/virtual-kubelet/virtual-kubelet.kubeconfig --nodename virtual-kubelet --os Linux --provider azure"

############
# virtual-kubelet (windows)
############

az container create -g $AZURE_RESOURCE_GROUP \
  --name virtual-kubelet-win \
  --image microsoft/virtual-kubelet \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name virtual-kubelet \
  --azure-file-volume-mount-path /etc/virtual-kubelet \
  -e AZURE_AUTH_LOCATION=/etc/virtual-kubelet/credentials.json ACI_RESOURCE_GROUP=frankenetes-pods ACI_REGION=$REGION \
  --command-line "/usr/bin/virtual-kubelet --provider azure --nodename virtual-kubelet-win --os Windows --kubeconfig /etc/virtual-kubelet/virtual-kubelet-win.kubeconfig"
