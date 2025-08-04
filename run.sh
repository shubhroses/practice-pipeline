#!/bin/bash
set -euo pipefail

# Configuration
REPO_DIR="/home/vagrant/hackathon-project"  # Corrected path
MANIFEST="k8s-deploy.yaml"
IMAGE_NAME="flask-demo"

echo "🚀 Starting DevSecOps Pipeline..."

echo "1. Bring up VM"
vagrant up --provider=qemu

echo "2. Upload project files to VM"
vagrant ssh -c "mkdir -p ${REPO_DIR}"
vagrant upload app.py ${REPO_DIR}/app.py
vagrant upload Dockerfile ${REPO_DIR}/Dockerfile  
vagrant upload requirements.txt ${REPO_DIR}/requirements.txt
vagrant upload k8s-deploy.yaml ${REPO_DIR}/k8s-deploy.yaml

echo "3. Build Docker image inside VM"
vagrant ssh -c "cd ${REPO_DIR} && docker build -t ${IMAGE_NAME} ."

echo "4. Import image into k3s containerd"
vagrant ssh -c "docker save ${IMAGE_NAME} | sudo k3s ctr images import -"

echo "5. Deploy to Kubernetes"
vagrant ssh -c "cd ${REPO_DIR} && sudo k3s kubectl apply -f ${MANIFEST}"

echo "6. Wait for deployment to be ready"
vagrant ssh -c "sudo k3s kubectl rollout status deployment/${IMAGE_NAME} --timeout=60s"

echo "7. Test application endpoints"
echo "   Testing main app..."
vagrant ssh -c "curl -s http://localhost:30007"
echo ""
echo "   Testing health check..."
vagrant ssh -c "curl -s http://localhost:30007/health | python3 -m json.tool"
echo ""
echo "   Testing readiness..."
vagrant ssh -c "curl -s http://localhost:30007/ready"
echo ""

echo "8. Show running pods and services"
vagrant ssh -c "sudo k3s kubectl get pods,services -o wide"

echo ""
echo "✅ DevSecOps Pipeline Complete!"
echo ""
echo "🔍 Access your application:"
echo "  vagrant ssh -c 'curl http://localhost:30007'"
echo "  vagrant ssh -c 'curl http://localhost:30007/health'"
echo ""
echo "📊 Monitor your deployment:"
echo "  vagrant ssh -c 'sudo k3s kubectl get pods'"
echo "  vagrant ssh -c 'sudo k3s kubectl logs deployment/flask-demo'"
echo ""
echo "🔄 For redeployments, use: ./deploy.sh"
