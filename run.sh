#!/bin/bash
set -euo pipefail

# Configuration
REPO_URL="https://github.com/shubhroses/practice-pipeline.git"
REPO_DIR="/home/vagrant/practice-pipeline"
IMAGE_NAME="flask-demo"
# Docker Hub settings: set DOCKERHUB_USER (e.g., export DOCKERHUB_USER=myuser)
DOCKERHUB_USER="shubhroses"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"

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

# 3. Build and tag
echo "3. Building Docker image"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME}:${IMAGE_TAG} . && docker tag ${IMAGE_NAME}:${IMAGE_TAG} docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

# 4. Push to Docker Hub (requires prior 'docker login' inside VM)
echo "4. Pushing image to Docker Hub"
vagrant ssh -c "docker push docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

# 5. Apply manifests
echo "5. Applying Kubernetes manifests"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f k8s-deploy.yaml"

# 6. Update deployment image to pull from registry
echo "6. Updating deployment image to docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
vagrant ssh -c "sudo k3s kubectl set image deployment/${IMAGE_NAME} flask=docker.io/${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} --record"

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
echo "📋 View logs: vagrant ssh -c 'sudo k3s kubectl logs -l app=${IMAGE_NAME} --tail=50'"
