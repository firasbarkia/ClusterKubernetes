#!/bin/bash
set -e

# Get Kubernetes version from first argument or use default if not provided
KUBERNETES_VERSION=${1:-1.32.0-00}

echo "[COMMON] Starting common setup..."

# Update system and install required packages
echo "[COMMON] Updating system and installing required packages..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

# Disable swap
echo "[COMMON] Disabling swap..."
swapoff -a
sed -i '/swap/d' /etc/fstab

# Load required modules
echo "[COMMON] Loading required kernel modules..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Set up kernel parameters
echo "[COMMON] Setting up kernel parameters..."
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install containerd using the updated method for adding the repository
echo "[COMMON] Installing containerd with updated repository method..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update && apt-get install -y containerd.io

# Configure containerd to use systemd cgroup driver
echo "[COMMON] Configuring containerd with systemd cgroup driver..."
mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubernetes components using the updated method for adding the repository
echo "[COMMON] Installing Kubernetes components..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

apt-get update

# Install specific Kubernetes version
echo "[COMMON] Installing Kubernetes version: ${KUBERNETES_VERSION}"
apt-get install -y kubelet=${KUBERNETES_VERSION} kubeadm=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION}
apt-mark hold kubelet kubeadm kubectl

# Display installed versions
INSTALLED_VERSION=$(kubectl version --client -o yaml | grep -i gitVersion | cut -d':' -f2 | tr -d ' ')
echo "[COMMON] Installed Kubernetes version: ${INSTALLED_VERSION}"

# Set up kubectl configuration directory for vagrant user
echo "[COMMON] Setting up kubectl configuration directory for vagrant user..."
mkdir -p /home/vagrant/.kube
chown -R vagrant:vagrant /home/vagrant/.kube

echo "[COMMON] Common setup completed successfully!"