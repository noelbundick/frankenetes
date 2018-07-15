export KUBECONFIG=$1

# Execute in the defaults directory
cd `dirname $0`/defaults

kubectl apply -f ClusterRoleBinding.yml
kubectl apply -f LimitRange.yml
