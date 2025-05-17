# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrant configuration for Kubernetes cluster with 1 master and 2 workers
# Includes Calico networking, kubectl without sudo, and Kubernetes dashboard

# Cluster configuration
MASTER_IP = "192.168.56.10"
POD_CIDR = "10.244.0.0/16"
SERVICE_CIDR = "10.96.0.0/12"
KUBERNETES_VERSION = "1.26.1"
DNS_DOMAIN = "cluster.local"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  # Configure master node
  config.vm.define "controlplane" do |master|
    master.vm.hostname = "controlplane"
    master.vm.network "private_network", ip: MASTER_IP
    
    # VM resource configuration
    master.vm.provider "virtualbox" do |vb|
      vb.name = "k8s-controlplane"
      vb.memory = 2048
      vb.cpus = 3
      vb.customize ["modifyvm", :id, "--ioapic", "on"]
    end
    
    # Provisioning
    master.vm.provision "file", source: "scripts/common-setup.sh", destination: "/tmp/common-setup.sh"
    master.vm.provision "file", source: "scripts/master-setup.sh", destination: "/tmp/master-setup.sh"
    master.vm.provision "shell", inline: "chmod +x /tmp/common-setup.sh && /tmp/common-setup.sh #{KUBERNETES_VERSION}"
    master.vm.provision "shell", inline: "chmod +x /tmp/master-setup.sh && /tmp/master-setup.sh #{MASTER_IP} #{POD_CIDR} #{SERVICE_CIDR} #{KUBERNETES_VERSION}"
    
    # Copy admin.conf to shared folder for worker nodes
    master.vm.provision "shell", inline: "cp /etc/kubernetes/admin.conf /vagrant/"
  end

  # Configure worker nodes
  (1..2).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: "192.168.56.#{i + 10}"
      
      # VM resource configuration
      worker.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-worker-#{i}"
        vb.memory = 4096
        vb.cpus = 1
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end
      
      # Provisioning
      worker.vm.provision "file", source: "scripts/common-setup.sh", destination: "/tmp/common-setup.sh"
      worker.vm.provision "file", source: "scripts/worker-setup.sh", destination: "/tmp/worker-setup.sh"
      worker.vm.provision "shell", inline: "chmod +x /tmp/common-setup.sh && /tmp/common-setup.sh #{KUBERNETES_VERSION}"
      worker.vm.provision "shell", inline: "chmod +x /tmp/worker-setup.sh && /tmp/worker-setup.sh"
    end
  end
end
