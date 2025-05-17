#!/bin/bash
set -e

# Get parameters from command line arguments
MASTER_IP=$1
POD_CIDR=$2
SERVICE_CIDR=$3
KUBERNETES_VERSION=${4:-1.32.0-00}

echo "[MASTER] Starting master node setup..."

# Initialize Kubernetes control-plane
echo "[MASTER] Initializing Kubernetes control-plane..."
kubeadm init --apiserver-advertise-address=${MASTER_IP} \
             --apiserver-cert-extra-sans=${MASTER_IP} \
             --pod-network-cidr=${POD_CIDR} \
             --service-cidr=${SERVICE_CIDR} \
             --kubernetes-version=${KUBERNETES_VERSION%-*} \
             --ignore-preflight-errors=NumCPU

# Set up kubectl access for root user
echo "[MASTER] Setting up kubectl access for root user..."
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Set up kubectl access for vagrant user
echo "[MASTER] Setting up kubectl access for vagrant user..."
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Install Calico network plugin
# Install Calico network plugin
echo "[MASTER] Installing Calico network plugin (v3.26.0) from Nexus registry..."
cat > calico-custom-resources.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${POD_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
  registry: 10.110.10.189:8087
  imagePullSecrets:
    - name: nexus-credentials
EOF

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/tigera-operator.yaml
kubectl create -f calico-custom-resources.yaml

# Wait for Calico to be ready
echo "[MASTER] Waiting for Calico to be ready..."
kubectl wait --for=condition=ready --timeout=300s pods -l k8s-app=calico-node -n calico-system || true

# Install Kubernetes Dashboard if version is specified
if [ -n "${5}" ]; then
  echo "[MASTER] Installing Kubernetes Dashboard (v2.7.0)..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

  # Create admin-user service account
  echo "[MASTER] Creating admin-user service account for Dashboard..."
  cat > dashboard-adminuser.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

  kubectl apply -f dashboard-adminuser.yaml

  # Generate and display token for dashboard
  echo "[MASTER] Generating token for Kubernetes Dashboard:"
  kubectl -n kubernetes-dashboard create token admin-user
fi

# Generate join command for worker nodes
echo "[MASTER] Generating join command for worker nodes..."
kubeadm token create --print-join-command > /vagrant/join.sh
chmod +x /vagrant/join.sh

echo "[MASTER] Master node setup completed successfully!"