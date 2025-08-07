
**Access Flow**: Host → Vagrant Port Forward → k3s NodePort → Flask Container

## Technology Stack & Decisions

### Core Technologies
- **VM**: Vagrant + Ubuntu 22.04 ARM64
- **Containerization**: Docker
- **Orchestration**: k3s (single-node Kubernetes)
- **Web Framework**: Flask (Python)
- **Provider**: QEMU (ARM64 compatibility)

### Key Technical Decisions

**1. k3s vs minikube**
- ✅ **Chose k3s**: Lightweight (~100MB), production-ready, faster startup
- ❌ minikube: Heavier, more development-focused, slower in VMs

**2. Flask vs Node.js**
- ✅ **Chose Flask**: Minimal setup, excellent Docker support, familiar Python ecosystem
- ❌ Node.js: More complex dependency management for simple apps

**3. QEMU vs VirtualBox**
- ✅ **Chose QEMU**: Native ARM64 support for Apple Silicon, better performance
- ❌ VirtualBox: Limited ARM64 support, compatibility issues on M1/M2

**4. Containerization Rationale**
- **Consistency**: Same environment dev → test → deploy
- **Security**: Non-root user, minimal attack surface
- **Portability**: Works anywhere Docker runs

## Prerequisites

- macOS with Apple Silicon (M1/M2) or Intel
- Vagrant installed (`brew install vagrant`)
- QEMU provider (`vagrant plugin install vagrant-qemu`)
- Git and basic command line tools

## Setup Instructions

### Quick Start (Automated)
```bash
# Clone the repository
git clone https://github.com/shubhroses/rhombus-hackathon.git
cd rhombus-hackathon

# Run the complete setup
./run.sh

# Test the application
vagrant ssh -c "curl http://localhost:30007"
```

### Manual Step-by-Step Setup

**1. Initialize VM**
```bash
# Start and provision VM (5-10 minutes first time)
vagrant up --provider=qemu

# Verify tools installed
vagrant ssh -c "docker --version && kubectl version --client && sudo systemctl status k3s"
```

**2. Upload Application Files**
```bash
# Create project directory
vagrant ssh -c "mkdir -p ~/hackathon-project"

# Upload files
vagrant upload app.py /home/vagrant/hackathon-project/app.py
vagrant upload Dockerfile /home/vagrant/hackathon-project/Dockerfile
vagrant upload requirements.txt /home/vagrant/hackathon-project/requirements.txt
vagrant upload k8s-deploy.yaml /home/vagrant/hackathon-project/k8s-deploy.yaml
```

**3. Build and Deploy**
```bash
# Build Docker image
vagrant ssh -c "cd ~/hackathon-project && docker build -t flask-demo ."

# Import to k3s
vagrant ssh -c "docker save flask-demo | sudo k3s ctr images import -"

# Deploy to Kubernetes
vagrant ssh -c "cd ~/hackathon-project && sudo k3s kubectl apply -f k8s-deploy.yaml"

# Verify deployment
vagrant ssh -c "sudo k3s kubectl get pods,services"
```

**4. Test Application**
```bash
# Test via NodePort
vagrant ssh -c "curl http://localhost:30007"

# Expected output: "Hello from Flask in k3s inside Vagrant!"
```

## Health Monitoring & Resilience

### Health Check Endpoints
- **`/health`**: Liveness probe - container health status
- **`/ready`**: Readiness probe - traffic readiness status
- **`/`**: Main application endpoint

### Kubernetes Probes
- **Liveness Probe**: Restarts unhealthy containers automatically
- **Readiness Probe**: Removes unready pods from load balancing
- **Resource Limits**: Prevents resource exhaustion

## Deployment & Management

### Redeploy Application
```bash
# After code changes
vagrant upload app.py /home/vagrant/hackathon-project/app.py
vagrant ssh -c "cd ~/hackathon-project && docker build -t flask-demo ."
vagrant ssh -c "docker save flask-demo | sudo k3s ctr images import -"
vagrant ssh -c "sudo k3s kubectl rollout restart deployment/flask-demo"
```

### Scale Application
```bash
# Scale to 3 replicas
vagrant ssh -c "sudo k3s kubectl scale deployment flask-demo --replicas=3"
```

### View Logs
```bash
# Application logs
vagrant ssh -c "sudo k3s kubectl logs deployment/flask-demo"

# Follow logs
vagrant ssh -c "sudo k3s kubectl logs -f deployment/flask-demo"
```

## Troubleshooting

### Quick Demo Troubleshooting (5 commands)
```bash
# 1) Describe the failing pod (status + Events)
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); echo POD=$POD; sudo k3s kubectl describe pod "$POD"'

# 2) Get logs (fallback to previous if crash-looping)
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); sudo k3s kubectl logs "$POD" --previous || sudo k3s kubectl logs "$POD"'

# 3) Fix image issues fast: rebuild → import into k3s → restart deployment
vagrant ssh -c 'cd ~/hackathon-project && docker build -t flask-demo . && docker save flask-demo | sudo k3s ctr images import - && sudo k3s kubectl rollout restart deployment/flask-demo'

# 4) Apply manifest changes (if you edited k8s-deploy.yaml)
vagrant ssh -c 'sudo k3s kubectl apply -f ~/hackathon-project/k8s-deploy.yaml'

# 5) Confirm health/readiness
vagrant ssh -c 'curl -sS http://localhost:30007/health && echo && curl -sS http://localhost:30007/ready && echo'
```

### Common Issues & Solutions

**1. VM Won't Start - Port Conflicts**
```bash
# Symptoms: "port already in use" errors
# Solution: Check and kill conflicting processes
lsof -i :5004  # Check Vagrant port
lsof -i :2223  # Check SSH port
vagrant destroy -f  # Clean restart
```

**2. Docker Build Fails**
```bash
# Symptoms: Build errors, package installation fails
# Solution: Check internet connectivity and try again
vagrant ssh -c "curl -I https://pypi.org"  # Test connectivity
vagrant ssh -c "cd ~/hackathon-project && docker build -t flask-demo ."
```

**3. k3s Pod in ErrImageNeverPull**
```bash
# Symptoms: Pod can't find Docker image
# Solution: Verify image import
vagrant ssh -c "sudo k3s ctr images list | grep flask"
vagrant ssh -c "docker save flask-demo | sudo k3s ctr images import -"
vagrant ssh -c "sudo k3s kubectl delete pod <pod-name>"  # Force restart
```

**4. Health Check Failures**
```bash
# Symptoms: Pod restarts frequently
# Solution: Check health endpoints
vagrant ssh -c "curl http://localhost:30007/health"
vagrant ssh -c "curl http://localhost:30007/ready"
vagrant ssh -c "sudo k3s kubectl describe pod <pod-name>"
```

**5. Network Connectivity Issues**
```bash
# Symptoms: Can't access application
# Solution: Verify service and port forwarding
vagrant ssh -c "sudo k3s kubectl get services"
vagrant ssh -c "curl http://localhost:30007"  # Test NodePort
```

**6. Pod Won't Start (CrashLoopBackOff / ImagePullBackOff / Pending)**
```bash
# Identify pod and check status/events
vagrant ssh -c 'sudo k3s kubectl get pods -o wide'
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); echo "POD=$POD"; sudo k3s kubectl describe pod "$POD"'
vagrant ssh -c 'sudo k3s kubectl get events --sort-by=.lastTimestamp | tail -n 25'
```

```bash
# Verify image reference and availability in k3s containerd
vagrant ssh -c 'sudo k3s kubectl get deployment flask-demo -o jsonpath="{.spec.template.spec.containers[0].image}"; echo'
vagrant ssh -c 'sudo k3s ctr images list | grep flask-demo || true'
```

```bash
# If image is missing or ImagePullBackOff/ErrImageNeverPull, rebuild, import, and restart
vagrant ssh -c 'cd ~/hackathon-project && docker build -t flask-demo . && docker save flask-demo | sudo k3s ctr images import - && sudo k3s kubectl rollout restart deployment/flask-demo'
```

```bash
# Inspect security context for conflicts (runAsNonRoot, dropped capabilities)
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); echo "Pod securityContext:"; sudo k3s kubectl get pod "$POD" -o jsonpath="{.spec.securityContext}"; echo; echo "Container securityContext:"; sudo k3s kubectl get pod "$POD" -o jsonpath="{.spec.containers[0].securityContext}"; echo'
```

```bash
# Check resource-related reasons (OOMKilled, CrashLoopBackOff) and limits
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); echo "State:"; sudo k3s kubectl get pod "$POD" -o jsonpath="{.status.containerStatuses[0].state}"; echo; echo "LastState:"; sudo k3s kubectl get pod "$POD" -o jsonpath="{.status.containerStatuses[0].lastState}"; echo'
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); sudo k3s kubectl describe pod "$POD" | sed -n "/Limits:/,/Environment:/p"'
```

```bash
# Get logs (use --previous if crash looping)
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); sudo k3s kubectl logs "$POD" --previous || sudo k3s kubectl logs "$POD"'
```

```bash
# Force a fresh pod (after fixing the cause)
vagrant ssh -c 'sudo k3s kubectl delete pod -l app=flask-demo'
```

```bash
# Validate probes if restarts are probe-related
vagrant ssh -c 'curl -sS http://localhost:30007/health; echo; curl -sS http://localhost:30007/ready; echo'
```

```bash
# Reapply manifest if needed (to pick up edits)
vagrant ssh -c 'sudo k3s kubectl apply -f ~/hackathon-project/k8s-deploy.yaml'
```

```bash
# Quick event tail for the specific pod
vagrant ssh -c 'POD=$(sudo k3s kubectl get pods -l app=flask-demo -o jsonpath="{.items[0].metadata.name}"); sudo k3s kubectl describe pod "$POD" | sed -n "/Events:/,$p"'
```

```bash
# Common recovery for ImagePullBackOff in this setup
vagrant ssh -c 'cd ~/hackathon-project && docker build -t flask-demo .'
vagrant ssh -c 'docker save flask-demo | sudo k3s ctr images import -'
vagrant ssh -c 'sudo k3s kubectl rollout restart deployment/flask-demo'
```

### Recovery Procedures

**Complete Reset**
```bash
vagrant destroy -f
rm -rf .vagrant/
vagrant up --provider=qemu
# Then follow setup instructions
```

**Kubernetes Reset**
```bash
vagrant ssh -c "sudo k3s kubectl delete -f ~/hackathon-project/k8s-deploy.yaml"
vagrant ssh -c "sudo k3s kubectl apply -f ~/hackathon-project/k8s-deploy.yaml"
```

## Demo Walkthrough for Panel

### 1. Architecture Overview (2 minutes)
"I've built a complete DevSecOps pipeline on a local VM to simulate an air-gapped environment..."

**Show**: Architecture diagram, explain VM → Docker → k3s → Flask flow

### 2. Live Demonstration (3 minutes)
```bash
# Show VM status
vagrant status

# Show running services
vagrant ssh -c "sudo k3s kubectl get all"

# Demonstrate application
vagrant ssh -c "curl http://localhost:30007"
vagrant ssh -c "curl http://localhost:30007/health"

# Show logs
vagrant ssh -c "sudo k3s kubectl logs deployment/flask-demo --tail=10"
```

### 3. Reliability Features (2 minutes)
"The system includes several reliability features..."

**Show**: Health checks, auto-restart, resource limits in k8s-deploy.yaml

### 4. DevSecOps Practices (2 minutes)
- **Infrastructure as Code**: Vagrantfile, Dockerfile, k8s manifests
- **Security**: Non-root containers, resource limits, health monitoring
- **Automation**: One-command deployment, reproducible builds

### 5. Scaling & Next Steps (1 minute)
```bash
# Demonstrate scaling
vagrant ssh -c "sudo k3s kubectl scale deployment flask-demo --replicas=3"
vagrant ssh -c "sudo k3s kubectl get pods"
```

**Next Steps**: CI/CD integration, secrets management, multi-node clusters, monitoring/observability

## Next Steps & Production Considerations

### Security Enhancements
- [ ] Image vulnerability scanning
- [ ] Secrets management (Vault integration)
- [ ] Network policies
- [ ] RBAC implementation
- [ ] TLS/SSL certificates

### Operational Improvements
- [ ] Prometheus monitoring
- [ ] Grafana dashboards
- [ ] Log aggregation (ELK stack)
- [ ] Backup strategies
- [ ] Multi-node cluster

### CI/CD Integration
- [ ] GitHub Actions workflow
- [ ] Automated testing
- [ ] Image registry
- [ ] GitOps deployment
- [ ] Rollback mechanisms

## Performance Metrics

- **VM Startup Time**: ~5-8 minutes (first time)
- **Application Deployment**: ~30 seconds
- **Memory Usage**: ~1.5GB (k3s + containers)
- **Recovery Time**: ~1 minute (pod restart)

---

**Project Author**: Shubhrose Singh  
**Created**: August 2025  
**Purpose**: Rhombus Power DevSecOps Engineer Interview