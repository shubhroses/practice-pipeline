#!/bin/bash
set -euo pipefail

echo "🔧 Starting complete teardown/rebuild test..."

# Teardown
echo "1. Destroying existing VM..."
vagrant destroy -f || true
rm -rf .vagrant/ || true

# Rebuild
echo "2. Starting fresh VM..."
time vagrant up --provider=qemu

echo "3. Verifying tools..."
vagrant ssh -c "docker --version && kubectl version --client && sudo systemctl status k3s --no-pager"

echo "4. Uploading files..."
vagrant ssh -c "mkdir -p ~/hackathon-project"
vagrant upload app.py /home/vagrant/hackathon-project/app.py
vagrant upload Dockerfile /home/vagrant/hackathon-project/Dockerfile
vagrant upload requirements.txt /home/vagrant/hackathon-project/requirements.txt
vagrant upload k8s-deploy.yaml /home/vagrant/hackathon-project/k8s-deploy.yaml

echo "5. Building and deploying..."
vagrant ssh -c "cd ~/hackathon-project && docker build -t flask-demo ."
vagrant ssh -c "docker save flask-demo | sudo k3s ctr images import -"
vagrant ssh -c "cd ~/hackathon-project && sudo k3s kubectl apply -f k8s-deploy.yaml"

echo "6. Waiting for deployment..."
sleep 30

echo "7. Testing app..."
vagrant ssh -c "sudo k3s kubectl get pods,services"
vagrant ssh -c "curl http://localhost:30007"

echo "✅ Teardown/rebuild test PASSED!"