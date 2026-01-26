# GitHub Actions Runner Container Image (Podman)

This project creates a custom GitHub Actions runner container image using Podman. The image is based on Red Hat Enterprise Linux (RHEL) 9 Universal Base Image (UBI) and can be used to run self-hosted GitHub Actions runners in containerized environments.

## Prerequisites

- Podman installed and configured
- GitHub repository access token with appropriate permissions
- Access to Red Hat Container Registry (registry.redhat.io) - may require authentication for some images

## Building the Image

### Using the Build Script

```bash
chmod +x build.sh
./build.sh
```

### Custom Image Name/Tag

```bash
IMAGE_NAME=my-runner IMAGE_TAG=v1.0 ./build.sh
```

### Manual Build

```bash
podman build -t github-actions-runner:latest -f Containerfile .
```

## Running the Runner

### Basic Usage

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  github-actions-runner:latest
```

### With Custom Runner Name

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  -e RUNNER_NAME=my-custom-runner \
  github-actions-runner:latest
```

### With Labels

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  -e RUNNER_LABELS=docker,linux \
  github-actions-runner:latest
```

### Ephemeral Runner (Auto-removes after job completion)

```bash
podman run -d \
  --name github-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  -e RUNNER_EPHEMERAL=true \
  github-actions-runner:latest
```

### With Volume for Persistence

```bash
podman run -d \
  --name github-runner \
  -v runner-data:/home/runner/actions-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  github-actions-runner:latest
```

### With Podman Support (Podman-in-Podman)

To enable Podman inside the container (for building container images in CI/CD):

**Option 1: Privileged Mode (Recommended for CI/CD)**
```bash
podman run -d \
  --name github-runner \
  --privileged \
  --device /dev/fuse \
  -v runner-data:/home/runner/actions-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  github-actions-runner:latest
```

**Option 2: Rootless Podman (More Secure)**
```bash
podman run -d \
  --name github-runner \
  --device /dev/fuse \
  --security-opt label=disable \
  --security-opt seccomp=unconfined \
  -v runner-data:/home/runner/actions-runner \
  -e GITHUB_REPOSITORY=owner/repo \
  -e GITHUB_TOKEN=your_github_token \
  github-actions-runner:latest
```

**Note:** The container includes Podman pre-installed and configured for rootless operation. The entrypoint script automatically initializes Podman storage on first run.

See `.github/workflows/example-podman.yml` for an example GitHub Actions workflow that uses Podman to build container images.

**Writing to Inner Containers**: Yes, you can write files to containers created by Podman! See `WRITING-TO-CONTAINERS.md` for detailed examples and methods for writing to inner containers using volume mounts, `podman exec`, and more.

## Using with Actions Runner Controller (ARC)

Yes! This image is fully compatible with **Actions Runner Controller (ARC)** for running GitHub Actions runners in Kubernetes with Podman-in-Podman support.

### Prerequisites

- Kubernetes cluster with ARC installed
- Your custom runner image pushed to a container registry accessible by your cluster
- GitHub App or Personal Access Token configured for ARC

### Quick Start with ARC

1. **Build and push your image:**
   ```bash
   ./build.sh
   podman tag github-actions-runner:latest your-registry/github-actions-runner:latest
   podman push your-registry/github-actions-runner:latest
   ```

2. **Deploy using RunnerDeployment:**
   ```bash
   # Edit arc-runner-deployment.yaml with your image and repository
   kubectl apply -f arc-runner-deployment.yaml
   ```

3. **Or deploy using RunnerScaleSet (recommended for newer ARC versions):**
   ```bash
   # Edit arc-runner-scale-set.yaml with your image and repository
   kubectl apply -f arc-runner-scale-set.yaml
   ```

### Important Configuration for Podman-in-Podman

When using this image with ARC, you **must** configure the following in your ARC manifests:

- **Privileged Mode**: Required for Podman-in-Podman
  ```yaml
  securityContext:
    privileged: true
    runAsUser: 0
  ```

- **Device Mount**: Mount `/dev/fuse` for fuse-overlayfs
  ```yaml
  volumes:
    - name: dev-fuse
      hostPath:
        path: /dev/fuse
        type: CharDevice
  volumeMounts:
    - name: dev-fuse
      mountPath: /dev/fuse
  ```

- **Podman Storage**: Use emptyDir for Podman storage (ephemeral) or PersistentVolumeClaim for persistence
  ```yaml
  volumes:
    - name: podman-storage
      emptyDir: {}
  volumeMounts:
    - name: podman-storage
      mountPath: /home/runner/.local/share/containers
  ```

### Example Files

- `arc-runner-deployment.yaml` - Example RunnerDeployment manifest
- `arc-runner-scale-set.yaml` - Example RunnerScaleSet manifest (newer ARC API)

### ARC Compatibility Notes

- **Automatic Detection**: The entrypoint script automatically detects ARC environment and skips manual configuration
- **Container Jobs**: For workflows using container jobs, ARC's `kubernetes` mode will run them as separate pods
- **Privileged Access**: Podman-in-Podman requires privileged containers, which has security implications. Evaluate your security requirements.
- **Storage**: Podman storage is ephemeral by default. Use PersistentVolumeClaims if you need persistent storage across pod restarts.

### Testing Podman in ARC Runners

Once deployed, you can test Podman in your workflows:

```yaml
- name: Test Podman
  run: |
    podman --version
    podman run --rm quay.io/podman/hello
    podman build -t test-image .
```

## Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `GITHUB_REPOSITORY` | Yes | GitHub repository in format `owner/repo` | - |
| `GITHUB_TOKEN` | Yes | GitHub personal access token or registration token | - |
| `RUNNER_NAME` | No | Custom name for the runner | `runner-<hostname>` |
| `RUNNER_LABELS` | No | Comma-separated labels for the runner | - |
| `RUNNER_GROUP` | No | Runner group name | - |
| `RUNNER_EPHEMERAL` | No | Set to `true` for ephemeral runners | `false` |

## Getting a GitHub Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Select scopes:
   - `repo` (for private repositories)
   - `admin:org` (for organization runners)
4. Copy the token and use it as `GITHUB_TOKEN`

Alternatively, for repository-level runners:
1. Go to your repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Copy the registration token from the setup instructions

## Features

- **Podman Support**: The image includes Podman and is configured to run Podman-in-Podman, allowing you to build container images within your GitHub Actions workflows
- **Rootless Podman**: Configured for secure rootless Podman operation
- **RHEL 9 UBI Base**: Built on Red Hat Enterprise Linux 9 Universal Base Image
- **ARC Compatible**: Works with Actions Runner Controller for Kubernetes deployments with automatic ARC detection

## Customization

### Adding Additional Tools

Edit the `Containerfile` to add more packages or tools:

```dockerfile
RUN dnf install -y \
    # ... existing packages ...
    nodejs \
    npm \
    python3 \
    buildah
```

### Using a Different Base Image

Change the `FROM` line in `Containerfile`:

```dockerfile
FROM registry.redhat.io/ubi9/ubi-minimal:latest
# or
FROM registry.redhat.io/ubi8/ubi:latest
```

**Note:** If you need to authenticate to Red Hat Container Registry, you may need to log in first:
```bash
podman login registry.redhat.io
```

## Troubleshooting

### Check Runner Status

```bash
podman logs github-runner
```

### Execute Commands in Container

```bash
podman exec -it github-runner bash
```

### Remove and Reconfigure

```bash
podman stop github-runner
podman rm github-runner
# Remove volume if using persistent storage
podman volume rm runner-data
```

### Testing Podman Inside Container

To verify Podman is working inside the container:

```bash
podman exec -it github-runner podman --version
podman exec -it github-runner podman run --rm quay.io/podman/hello
```

### Podman Permission Issues

If you encounter permission issues with Podman:

1. Ensure the container is running with `--device /dev/fuse`
2. For rootless Podman, ensure subuid/subgid mappings are correct
3. Check Podman storage initialization:
   ```bash
   podman exec -it github-runner podman system info
   ```

## Security Considerations

- Never commit tokens or secrets to version control
- Use environment variables or Podman secrets for sensitive data
- Consider using ephemeral runners for better security
- Regularly update the runner version in the Containerfile

## License

This project is provided as-is for creating custom GitHub Actions runner images.
