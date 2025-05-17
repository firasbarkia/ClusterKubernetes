#!/bin/bash
set -e

# Get Kubernetes version from first argument
KUBERNETES_VERSION=$1

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

# Install containerd
echo "[COMMON] Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update && apt-get install -y containerd.io

# Configure containerd to use systemd cgroup driver
echo "[COMMON] Configuring containerd with systemd cgroup driver..."
mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubernetes components
echo "[COMMON] Installing Kubernetes components (v${KUBERNETES_VERSION})..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet=${KUBERNETES_VERSION}-00 kubeadm=${KUBERNETES_VERSION}-00 kubectl=${KUBERNETES_VERSION}-00
apt-mark hold kubelet kubeadm kubectl

# Set up kubectl configuration directory for vagrant user
echo "[COMMON] Setting up kubectl configuration directory for vagrant user..."
mkdir -p /home/vagrant/.kube
chown -R vagrant:vagrant /home/vagrant/.kube

echo "[COMMON] Common setup completed successfully!"