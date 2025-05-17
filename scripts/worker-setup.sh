#!/bin/bash
set -e

echo "[WORKER] Starting worker node setup..."

# Join the Kubernetes cluster
echo "[WORKER] Joining the Kubernetes cluster..."
/vagrant/join.sh

# Set up kubectl configuration for vagrant user
echo "[WORKER] Setting up kubectl access for vagrant user..."
mkdir -p /home/vagrant/.kube
cp /vagrant/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

echo "[WORKER] Worker node setup completed successfully!"