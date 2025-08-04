#!/bin/bash
set -euo pipefail

# Note: Using manual file upload instead of synced folders for QEMU provider
REPO_DIR="$HOME/rhombus-project"
MANIFEST="k8s-deploy.yaml"
IMAGE_NAME="flask-demo"

echo "1. Bring up VM"
vagrant up --provider=qemu

echo "2. Upload project files to VM"
vagrant ssh -c "mkdir -p ${REPO_DIR}"
vagrant upload app.py ${REPO_DIR}/
vagrant upload Dockerfile ${REPO_DIR}/
vagrant upload requirements.txt ${REPO_DIR}/
vagrant upload k8s-deploy.yaml ${REPO_DIR}/

echo "3. Build image inside VM"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "4. Import into k3s containerd"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "5. Apply k8s manifest and wait"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f ${MANIFEST} && sudo k3s kubectl rollout status deployment/${IMAGE_NAME}"

echo "✅ Done. To access the app:"
echo "  vagrant ssh -c 'curl http://localhost:30007'"
echo ""
echo "Or from host machine (if you want to set up port forwarding):"
echo "  vagrant ssh -- -L 8080:localhost:30007"
echo "  then: curl http://localhost:8080"
