Vagrant.configure("2") do |config|
    # Use ARM64-specific Ubuntu 22.04 base box (for Apple Silicon Macs)
    config.vm.box = "perk/ubuntu-2204-arm64"
  
    # Port forwarding - using available ports
    config.vm.network "forwarded_port", guest: 5000, host: 5004
    config.vm.network "forwarded_port", guest: 22, host: 2223
  
    # QEMU provider settings
    config.vm.provider :qemu do |q|
      q.memory = "4096"
      q.cpus = 2
    end
  
    # Provision VM with tools
    config.vm.provision "shell", inline: <<-SHELL
      set -e
      apt-get update -y
      apt-get install -y curl git bash-completion
  
      # Install Docker
      curl -fsSL https://get.docker.com | sh
      usermod -aG docker vagrant
  
      # Install latest stable kubectl for arm64
      KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
      curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"
      chmod +x kubectl
      mv kubectl /usr/local/bin/
  
      # Install k3s
      curl -sfL https://get.k3s.io | sh
  
      # Alias kubectl to k3s kubectl
      echo 'alias kubectl="k3s kubectl"' >> /home/vagrant/.bashrc
  
      sleep 10
      /usr/local/bin/k3s kubectl get nodes || true
    SHELL
  end 
  