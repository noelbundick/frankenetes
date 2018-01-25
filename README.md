# frankenetes

Kubernetes control plane on Azure Container Instances

## Description

This repo is my work-in-progress to run a "virtual cluster" on top of Azure Container Instances

Read more here:
[https://www.noelbundick.com/2018/01/22/Frankenetes-Running-the-Kubernetes-control-plane-on-Azure-Container-Instances/](https://www.noelbundick.com/2018/01/22/Frankenetes-Running-the-Kubernetes-control-plane-on-Azure-Container-Instances/)

## Usage

```shell
./frankenetes.sh frankenetes frankenetes frankenetes-etcd.noelbundick.com frankenetes-apiserver.noelbundick.com

export KUBECONFIG=frankenetes.kubeconfig

# Run something!
kubectl run nginx --image=nginx --requests 'cpu=1,memory=1G'
```

## Cleanup

```shell
for aci in `az container list -g frankenetes --query "[].name" -o tsv`; do az container delete -n $aci -g frankenetes -y; done
for aci in `az container list -g frankenetes-pods --query "[].name" -o tsv`; do az container delete -n $aci -g frankenetes-pods -y; done
```