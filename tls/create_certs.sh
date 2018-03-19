ETCD_FQDN=$1
APISERVER_FQDN=$2

# Execute in the script directory
cd `dirname $0`

# Create a new Certificate Authority
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# etcd
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$ETCD_FQDN,127.0.0.1 \
  -profile=kubernetes \
  etcd-csr.json | cfssljson -bare etcd

# apiserver
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$APISERVER_FQDN,127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# Generate the admin client certificate
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# kube-controller-manager
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# kube-scheduler
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

# virtual-kubelet node
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=virtual-kubelet \
  -profile=kubernetes \
  virtual-kubelet-csr.json | cfssljson -bare virtual-kubelet

# virtual-kubelet-win node
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=virtual-kubelet-win \
  -profile=kubernetes \
  virtual-kubelet-win-csr.json | cfssljson -bare virtual-kubelet-win