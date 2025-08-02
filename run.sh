#!/bin/bash
set -euo pipefail

REPO_DIR="rhombus-hackathon"
MANIFEST="k8s-deploy.yaml"
IMAGE_NAME="flask-demo"

echo "1. Bringing up VM (QEMU/ARM64)..."
vagrant up --provider=qemu

echo "2. Building Docker image inside VM..."
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "3. Import image into k3s containerd (so k3s can use it)"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "4. Applying k8s manifest and waiting for rollout..."
vagrant ssh -c "cd ${REPO_DIR} && kubectl apply -f ${MANIFEST} && kubectl rollout status deployment/${IMAGE_NAME}"

echo "✅ Deployment should be up. Pod & service status:"
vagrant ssh -c "cd ${REPO_DIR} && kubectl get pods -l app=${IMAGE_NAME} -o wide && kubectl get svc flask-service"

echo
echo "➡ To access the service via port-forward:"
echo "  vagrant ssh -c 'kubectl port-forward service/flask-service 5000:5000'"
echo "  then on your host: curl http://localhost:5000"

