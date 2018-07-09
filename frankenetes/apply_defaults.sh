export KUBECONFIG=$1

# Execute in the script directory
cd `dirname $0`

kubectl apply -f ClusterRoleBinding.yml
kubectl apply -f LimitRange.yml
