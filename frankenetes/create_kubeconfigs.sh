APISERVER_FQDN=$1
CERTS_DIR=$2
OUTPUT_DIR=$3

############
# create admin kubeconfig
############
ADMIN_KUBECONFIG=$OUTPUT_DIR/admin.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=$CERTS_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$ADMIN_KUBECONFIG
kubectl config set-credentials admin \
  --client-certificate=$CERTS_DIR/admin.pem \
  --client-key=$CERTS_DIR/admin-key.pem \
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
  --certificate-authority=$CERTS_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config set-credentials controller-manager \
  --client-certificate=$CERTS_DIR/kube-controller-manager.pem \
  --client-key=$CERTS_DIR/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=controller-manager \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$CONTROLLER_MANAGER_KUBECONFIG

echo "controller manager kubeconfig created at $CONTROLLER_MANAGER_KUBECONFIG"
cp $CONTROLLER_MANAGER_KUBECONFIG /controllermanager/controller-manager.kubeconfig

############
# create scheduler kubeconfig
############
SCHEDULER_KUBECONFIG=$OUTPUT_DIR/scheduler.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=$CERTS_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config set-credentials scheduler \
  --client-certificate=$CERTS_DIR/kube-scheduler.pem \
  --client-key=$CERTS_DIR/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=scheduler \
  --kubeconfig=$SCHEDULER_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$SCHEDULER_KUBECONFIG

echo "scheduler kubeconfig created at $SCHEDULER_KUBECONFIG"
cp $SCHEDULER_KUBECONFIG /scheduler/scheduler.kubeconfig

############
# create virtual-kubelet kubeconfig
############
VK_KUBECONFIG=$OUTPUT_DIR/virtual-kubelet.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=$CERTS_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$VK_KUBECONFIG
kubectl config set-credentials system:node:virtual-kubelet \
  --client-certificate=$CERTS_DIR/virtual-kubelet.pem \
  --client-key=$CERTS_DIR/virtual-kubelet-key.pem \
  --embed-certs=true \
  --kubeconfig=$VK_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=system:node:virtual-kubelet \
  --kubeconfig=$VK_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$VK_KUBECONFIG

echo "virtual-kubelet kubeconfig created at $VK_KUBECONFIG"
cp $VK_KUBECONFIG /virtualkubelet/virtual-kubelet.kubeconfig

############
# create virtual-kubelet-win kubeconfig
############
VK_WIN_KUBECONFIG=$OUTPUT_DIR/virtual-kubelet-win.kubeconfig

kubectl config set-cluster frankenetes \
  --certificate-authority=$CERTS_DIR/ca.pem \
  --embed-certs=true \
  --server="https://$APISERVER_FQDN:6443" \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config set-credentials system:node:virtual-kubelet-win \
  --client-certificate=$CERTS_DIR/virtual-kubelet-win.pem \
  --client-key=$CERTS_DIR/virtual-kubelet-win-key.pem \
  --embed-certs=true \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config set-context frankenetes \
  --cluster=frankenetes \
  --user=system:node:virtual-kubelet-win \
  --kubeconfig=$VK_WIN_KUBECONFIG
kubectl config use-context frankenetes \
  --kubeconfig=$VK_WIN_KUBECONFIG

echo "virtual-kubelet-win kubeconfig created at $VK_WIN_KUBECONFIG"
cp $VK_WIN_KUBECONFIG /virtualkubelet/virtual-kubelet-win.kubeconfig