#!/bin/bash

############
# Azure setup
############

AZURE_RESOURCE_GROUP=frankenetes

# As of 2.0.25, you have to set 'export'
# https://github.com/Azure/azure-cli/issues/5358
export AZURE_STORAGE_ACCOUNT=frankenetes

az group create -n $AZURE_RESOURCE_GROUP -l eastus
az storage account create -n $AZURE_STORAGE_ACCOUNT -g $AZURE_RESOURCE_GROUP

AZURE_STORAGE_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $AZURE_RESOURCE_GROUP --query '[0].value' -o tsv)

############
# etcd
############

# Create an Azure File share to hold cluster data
az storage share create -n etcd

#TODO: Implement cert auth for a secure etcd cluster
#TODO: Predefine DNS names, create ACI to get IP's, then update DNS when the container comes up. Use Event Grid + Azure Functions
#az storage file upload -s etcd --source ./kubernetes.pem -p certs/kubernetes.pem
#az storage file upload -s etcd --source ./kubernetes-key.pem -p certs/kubernetes-key.pem
#az storage file upload -s etcd --source ./ca.pem -p certs/ca.pem

#WARNING! This isn't useful until I fix the write ahead log & secure the cluster
#TODO: figure out why I get "create wal error: rename /etcd/data/member/wal.tmp /etcd/data/member/wal: permission denied" when --wal-dir is not set
#TODO: 3.3 errors out with "etcdserver: publish error: etcdserver: request timed out"
az container create -g $AZURE_RESOURCE_GROUP \
  --name etcd \
  --image quay.io/coreos/etcd:v3.2.8 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name etcd \
  --azure-file-volume-mount-path /etcd \
  --ports 2379 2389 \
  --ip-address public \
  --command-line '/usr/local/bin/etcd --name=aci --data-dir=/etcd/data --wal-dir=/etcd-wal --listen-client-urls=http://0.0.0.0:2379 --advertise-client-urls=http://frankenetes-etcd.noelbundick.com:2379'

############
# apiserver
############

# Create a share to hold certs/logs/etc
az storage share create -n apiserver

#TODO: secure apiserver
#TODO: secure connection to etcd
az container create -g $AZURE_RESOURCE_GROUP \
  --name apiserver \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name apiserver \
  --azure-file-volume-mount-path /apiserverdata \
  --ports 6445 \
  --ip-address public \
  --command-line '/apiserver  --advertise-address=0.0.0.0 --allow-privileged=true --apiserver-count=1 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/apiserverdata/log/audit.log --authorization-mode=Node,RBAC --bind-address=0.0.0.0 --etcd-servers=http://frankenetes-etcd.noelbundick.com:2379 --runtime-config=api/all --v=2 --runtime-config=admissionregistration.k8s.io/v1alpha1 --enable-swagger-ui=true --event-ttl=1h --service-node-port-range=30000-32767 --insecure-bind-address=0.0.0.0 --insecure-port 6445'
  
# --admission-control=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
# --client-ca-file=/var/lib/kubernetes/ca.pem \
# --etcd-cafile=/var/lib/kubernetes/ca.pem \
# --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \
# --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \
# --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \
# --insecure-bind-address=127.0.0.1 \
# --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
# --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \
# --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \
# --kubelet-https=true \
# --service-account-key-file=/var/lib/kubernetes/ca-key.pem \
# --service-cluster-ip-range=10.32.0.0/24 \
# --tls-ca-file=/var/lib/kubernetes/ca.pem \
# --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
# --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \

############
# controller manager
############

# Create a share to hold certs/logs/etc
az storage share create -n controllermanager

#TODO: add tls
az container create -g $AZURE_RESOURCE_GROUP \
  --name controllermanager \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name controllermanager \
  --azure-file-volume-mount-path /controllermanagerdata \
  --command-line '/controller-manager --address=0.0.0.0 --cluster-cidr=10.200.0.0/16 --cluster-name=kubernetes --leader-elect=true --master=http://frankenetes-apiserver.noelbundick.com:6445 --service-cluster-ip-range=10.32.0.0/24 --v=2'

  # --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  # --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  # --root-ca-file=/var/lib/kubernetes/ca.pem \\
  # --service-account-private-key-file=/var/lib/kubernetes/ca-key.pem \\

############
# scheduler
############

# Create a share to hold certs/logs/etc
az storage share create -n scheduler

#TODO: add tls
az container create -g $AZURE_RESOURCE_GROUP \
  --name scheduler \
  --image gcr.io/google-containers/hyperkube-amd64:v1.9.2 \
  --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT \
  --azure-file-volume-account-key $AZURE_STORAGE_KEY \
  --azure-file-volume-share-name scheduler \
  --azure-file-volume-mount-path /schedulerdata \
  --command-line '/scheduler --leader-elect=true --master=http://frankenetes-apiserver.noelbundick.com:6445 --v=2'