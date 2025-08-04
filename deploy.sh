#!/bin/bash
set -euo pipefail

# Quick redeployment script for code changes
REPO_DIR="/home/vagrant/hackathon-project"
IMAGE_NAME="flask-demo"

echo "🔄 Redeploying Flask application..."

echo "1. Upload updated files"
vagrant upload app.py ${REPO_DIR}/app.py
vagrant upload k8s-deploy.yaml ${REPO_DIR}/k8s-deploy.yaml

echo "2. Rebuild Docker image"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "3. Import updated image"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "4. Apply manifest changes"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f k8s-deploy.yaml"

echo "5. Restart deployment with new image"
vagrant ssh -c "sudo k3s kubectl rollout restart deployment/${IMAGE_NAME}"

echo "6. Wait for rollout"
vagrant ssh -c "sudo k3s kubectl rollout status deployment/${IMAGE_NAME} --timeout=60s"

echo "7. Test updated application"
vagrant ssh -c "curl -s http://localhost:30007"
echo ""
vagrant ssh -c "curl -s http://localhost:30007/health | python3 -m json.tool"

echo ""
echo "✅ Redeployment complete!" 