# frankenetes

Virtual Kubernetes cluster on Azure Container Instances

## Description

This repo is my work-in-progress to run a "virtual cluster" on top of Azure Container Instances

Read more here:
[https://www.noelbundick.com/2018/01/22/Frankenetes-Running-the-Kubernetes-control-plane-on-Azure-Container-Instances/](https://www.noelbundick.com/2018/01/22/Frankenetes-Running-the-Kubernetes-control-plane-on-Azure-Container-Instances/)

## Usage

1. Create a Service Principal for virtual-kubelet

```shell
# Create a service principal
# Tip: the following terms are synonymous: clientId<->appId, clientSecret<->password
az ad sp create-for-rbac -n frankenetes --skip-assignment
```

2. Create a virtual Kubernetes cluster

```shell
az group create -n frankenetes -l eastus
az group deployment create -g frankenetes --template-file ./azuredeploy.json --parameters servicePrincipalClientId=<clientId> servicePrincipalClientSecret=<clientSecret> servicePrincipalObjectId=<objectId> --query 'properties.outputs.kubeconfig.value' -o tsv

# Download the kubeconfig from Azure Files
# The exact command to run is an output of the deployment
az storage file download --account-name <storageAccountName> -s kubeconfigs -p admin.kubeconfig
export KUBECONFIG=admin.kubeconfig
```

3. Run something!

Frankenetes runs two virtual-kubelets, so it's a hybrid-OS cluster!

You can run Linux containers:

```shell
# Run nginx
kubectl run nginx --image=nginx --port 80

# Hit the deployed pod
NGINX_IP=`kubectl get pod -l run=nginx -o=jsonpath='{.items[0].status.podIP}'`
curl $NGINX_IP
```

Or Windows containers:

```shell
# Run IIS
k run iis --image=microsoft/iis:nanoserver-sac2016 --port=80

# Hit the deployed pod
IIS_IP=`kubectl get pod -l run=iis -o=jsonpath='{.items[0].status.podIP}'`
curl $IIS_IP
```

## Cleanup

To remove the cluster completely, delete the resource groups:

```shell
az group delete -n frankenetes -y --no-wait
```

To stop all compute, but leave your cluster configuration intact, delete just your Azure Container Instances:

```shell
for aci in `az container list -g frankenetes --query "[].name" -o tsv`; do az container delete -n $aci -g frankenetes -y; done
```