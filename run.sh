#!/bin/bash
set -euo pipefail

# Configuration
REPO_URL="https://github.com/shubhroses/rhombus-hackathon.git"
REPO_DIR="/home/vagrant/rhombus-hackathon"
IMAGE_NAME="flask-demo"

echo "🚀 DevSecOps Pipeline..."

# 1. Ensure VM is running
echo "1. Starting VM (if not already running)"
vagrant up --provider=qemu

# 2. Smart repo handling - clone or pull
echo "2. Getting latest code from GitHub"
vagrant ssh -c "
  if [ -d ${REPO_DIR} ]; then
    echo '   → Repository exists, pulling latest changes...'
    cd ${REPO_DIR} && git pull origin main
  else
    echo '   → Cloning repository for first time...'
    git clone ${REPO_URL} ${REPO_DIR}
  fi
"

# 3. Build and deploy
echo "3. Building Docker image"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "4. Importing to k3s"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "5. Deploying to Kubernetes"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f k8s-deploy.yaml"

echo "6. Restarting deployment (ensures new image is used)"
vagrant ssh -c "sudo k3s kubectl rollout restart deployment/${IMAGE_NAME}"

echo "7. Waiting for deployment"
vagrant ssh -c "sudo k3s kubectl rollout status deployment/${IMAGE_NAME} --timeout=60s"

# 8. Test the app
echo "8. Testing application"
echo "   Main app:"
vagrant ssh -c "curl -s http://localhost:30007"
echo ""
echo "   Health check:"
vagrant ssh -c "curl -s http://localhost:30007/health | python3 -m json.tool"
echo ""
echo "   Readiness check:"
vagrant ssh -c "curl -s http://localhost:30007/ready"

echo ""
echo "✅ Pipeline complete!"
echo ""
echo "🔍 Your app is running at: vagrant ssh -c 'curl http://localhost:30007'"
echo "📊 Check status: vagrant ssh -c 'sudo k3s kubectl get pods'"
