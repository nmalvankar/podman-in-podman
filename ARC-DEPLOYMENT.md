# Actions Runner Controller (ARC) Deployment Guide

This guide provides step-by-step instructions for deploying this GitHub Actions runner image with Podman-in-Podman support using Actions Runner Controller.

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (1.20+)
2. **ARC Installed**: Actions Runner Controller installed in your cluster
3. **Container Registry**: Access to push/pull container images
4. **GitHub Authentication**: GitHub App or PAT configured in ARC

## Step 1: Build and Push the Image

```bash
# Build the image
./build.sh

# Tag for your registry
podman tag github-actions-runner:latest your-registry/github-actions-runner:latest

# Push to registry
podman push your-registry/github-actions-runner:latest
```

## Step 2: Configure ARC Authentication

ARC needs to authenticate with GitHub. You can use either:

- **GitHub App** (recommended for production)
- **Personal Access Token (PAT)**

See [ARC documentation](https://github.com/actions-runner-controller/actions-runner-controller) for authentication setup.

## Step 3: Deploy Runner

### Option A: RunnerDeployment (Static Runners)

Edit `arc-runner-deployment.yaml`:

```yaml
spec:
  template:
    spec:
      image: your-registry/github-actions-runner:latest  # Update this
      repository: your-org/your-repo  # Update this
```

Apply:

```bash
kubectl apply -f arc-runner-deployment.yaml
```

### Option B: RunnerScaleSet (Auto-scaling Runners)

Edit `arc-runner-scale-set.yaml`:

```yaml
spec:
  template:
    spec:
      image: your-registry/github-actions-runner:latest  # Update this
      repository: your-org/your-repo  # Update this
```

Apply:

```bash
kubectl apply -f arc-runner-scale-set.yaml
```

## Step 4: Verify Deployment

```bash
# Check runner pods
kubectl get pods -n actions-runner-system

# Check runner logs
kubectl logs -n actions-runner-system -l runner-deployment=podman-runner-deployment

# Verify runner appears in GitHub
# Go to: Repository → Settings → Actions → Runners
```

## Step 5: Test Podman in Workflows

Create a test workflow (`.github/workflows/test-podman.yml`):

```yaml
name: Test Podman

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Check Podman
        run: podman --version
      
      - name: Run test container
        run: podman run --rm quay.io/podman/hello
      
      - name: Build test image
        run: |
          echo "FROM quay.io/podman/hello" > Dockerfile
          podman build -t test-image .
          podman images
```

## Important Configuration Notes

### Privileged Mode

Podman-in-Podman requires privileged containers. This is configured in the manifests:

```yaml
securityContext:
  privileged: true
  runAsUser: 0
```

**Security Consideration**: Privileged containers have elevated access. Only use in trusted environments.

### Storage Options

**Ephemeral Storage** (default in manifests):
- Uses `emptyDir`
- Data is lost when pod restarts
- Good for stateless builds

**Persistent Storage**:
```yaml
volumes:
  - name: podman-storage
    persistentVolumeClaim:
      claimName: podman-storage-pvc
```

### Network Configuration

For workflows that need to push images to registries, ensure:
- Network policies allow outbound connections
- Registry credentials are configured in workflows
- DNS resolution works correctly

## Troubleshooting

### Podman Not Working

1. **Check device mount**:
   ```bash
   kubectl exec -it <pod-name> -n actions-runner-system -- ls -la /dev/fuse
   ```

2. **Check Podman version**:
   ```bash
   kubectl exec -it <pod-name> -n actions-runner-system -- podman --version
   ```

3. **Check Podman storage**:
   ```bash
   kubectl exec -it <pod-name> -n actions-runner-system -- podman system info
   ```

### Runner Not Appearing in GitHub

1. Check ARC controller logs:
   ```bash
   kubectl logs -n actions-runner-system -l app=actions-runner-controller
   ```

2. Verify GitHub authentication in ARC
3. Check runner pod logs for errors

### Permission Issues

If you see permission errors:
- Ensure `privileged: true` is set
- Verify `/dev/fuse` is mounted
- Check that `runAsUser: 0` is set (for privileged mode)

## Advanced Configuration

### Custom Labels

Add labels to match specific workflows:

```yaml
labels:
  - podman
  - linux
  - rhel9
  - self-hosted
```

### Resource Limits

Add resource constraints:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Node Selectors

Run on specific nodes:

```yaml
nodeSelector:
  node-type: runner
```

## References

- [Actions Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller)
- [ARC Documentation](https://github.com/actions-runner-controller/actions-runner-controller/blob/master/docs/)
- [Podman Documentation](https://docs.podman.io/)
