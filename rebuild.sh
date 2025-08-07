#!/bin/bash
set -euo pipefail

# Configuration (same as run.sh)
REPO_URL="https://github.com/shubhroses/practice-pipeline.git"
REPO_DIR="/home/vagrant/practice-pipeline"
IMAGE_NAME="flask-demo"

echo "🔧 Starting complete teardown/rebuild test..."

# 1. Teardown
echo "1. Destroying existing VM..."
vagrant destroy -f || true
rm -rf .vagrant/ || true

# 2. Fresh rebuild
# lsof -i :5004
# sudo kill -9 <pid>
echo "2. Starting fresh VM..."
time vagrant up --provider=qemu

# 3. Verify tools
echo "3. Verifying tools..."
vagrant ssh -c "docker --version && kubectl version --client && sudo systemctl status k3s --no-pager"

# 4. Clone repository (like run.sh)
echo "4. Cloning repository..."
vagrant ssh -c "git clone ${REPO_URL} ${REPO_DIR}"

# 5. Build and deploy (same as run.sh)
echo "5. Building Docker image"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "6. Importing to k3s"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "7. Deploying to Kubernetes"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f k8s-deploy.yaml"

echo "8. Waiting for deployment"
vagrant ssh -c "sudo k3s kubectl rollout status deployment/${IMAGE_NAME} --timeout=60s"

# 9. Test the app (same comprehensive testing as run.sh)
echo "9. Testing application"
echo "   Main app:"
vagrant ssh -c "curl -s http://localhost:30007"
echo ""
echo "   Health check:"
vagrant ssh -c "curl -s http://localhost:30007/health | python3 -m json.tool"
echo ""
echo "   Readiness check:"
vagrant ssh -c "curl -s http://localhost:30007/ready"

echo ""
echo "✅ Teardown/rebuild test PASSED!"
echo ""
echo "🔍 Your app is running at: vagrant ssh -c 'curl http://localhost:30007'"
echo "📊 Check status: vagrant ssh -c 'sudo k3s kubectl get pods'"
echo "📋 View logs: vagrant ssh -c 'sudo k3s kubectl logs -l app=${IMAGE_NAME} --tail=50'"