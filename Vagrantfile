require 'rbconfig'
arch = RbConfig::CONFIG['host_cpu']
box = if arch.include?("arm") || arch.include?("aarch64")
        "perk/ubuntu-2204-arm64"
      else
        "generic/ubuntu2204"
      end

Vagrant.configure("2") do |config|
  config.vm.box = box

  # Forward the Flask app port so host can access it
  config.vm.network "forwarded_port", guest: 5000, host: 5001
  config.vm.network "forwarded_port", guest: 22, host: 2222

  config.vm.provider :qemu do |q|
    q.memory = "4096"
    q.cpus = 2
    # On macOS you can rely on HVF acceleration; if needed explicitly:
    # q.machine = "virt,accel=hvf,highmem=off"
  end

  # Provisioning script (adjusted for proper kubectl arch)
  config.vm.provision "shell", inline: <<-SHELL
    set -e

    # Update and basic tools
    apt-get update -y
    apt-get install -y curl git bash-completion

    # Install Docker (official install)
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker vagrant

    # Install kubectl matching guest architecture
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    ARCH=\$(uname -m)
    if [ "\$ARCH" = "aarch64" ]; then
      KUBE_ARCH=arm64
    else
      KUBE_ARCH=amd64
    fi
    curl -LO "https://dl.k8s.io/release/\${KUBECTL_VERSION}/bin/linux/\${KUBE_ARCH}/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/

    # Install k3s (lightweight Kubernetes)
    curl -sfL https://get.k3s.io | sh

    # Wait a bit for cluster
    sleep 10

    # Enable kubectl bash completion
    echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc

    # Small test: show nodes (non-fatal)
    /usr/local/bin/kubectl get nodes || true
  SHELL
end

