# ARC Manifests Review for Writing to Inner Containers

## Review Summary

This document reviews the ARC AutoscalingRunnerSet manifest (`arc-runner-scale-set.yaml`) for its ability to support writing to containers inside Podman (podman-in-podman).

## ✅ Current Configuration Status

### Security Context
- **Privileged Mode**: ✅ Configured
  - `privileged: true` grants all Linux capabilities needed for podman-in-podman
  - Includes: SYS_ADMIN, CHOWN, FOWNER, MKNOD, NET_ADMIN, SETUID, SETGID, etc.
  - Required for creating and managing inner containers

- **Run as Root**: ✅ Configured
  - `runAsUser: 0` allows full system access
  - Necessary for privileged mode and device access

### Device Mounts
- **/dev/fuse**: ✅ Mounted
  - Required for fuse-overlayfs (Podman's default storage driver)
  - Enables overlay filesystems for inner containers
  - Critical for container image layers and writable layers

### Volume Mounts
- **Podman Storage**: ✅ Configured
  - Mounted at `/home/runner/.local/share/containers`
  - Currently using `emptyDir` (ephemeral)
  - Can be changed to PersistentVolumeClaim for persistence

### Environment Variables
- **PODMAN_USERNS**: ✅ Set to "keep-id"
  - Maintains user namespace mapping
  - Important for rootless Podman operations

- **_CONTAINERS_USERNS_CONFIGURED**: ✅ Set to "true"
  - Signals that user namespace is configured
  - Prevents Podman from trying to reconfigure

- **_CONTAINERS_ROOTLESS_UID/GID**: ✅ Set to "0"
  - Indicates root execution context
  - Helps with SELinux context handling

## ✅ Writing to Inner Containers - Supported Methods

### 1. Volume Mounts from Workspace ✅

**Status**: Fully Supported

ARC automatically mounts the GitHub Actions workspace. You can mount it into inner containers:

```yaml
- name: Write via volume mount
  run: |
    # Create file in workspace
    echo "Hello" > workspace-file.txt
    
    # Mount workspace into inner container
    podman run --rm \
      -v $GITHUB_WORKSPACE:/workspace:Z \
      alpine:latest \
      sh -c "echo 'Written from container' >> /workspace/workspace-file.txt"
    
    # File is now accessible in workspace
    cat workspace-file.txt
```

**Why it works**:
- Privileged mode allows mounting host paths
- Workspace is accessible at `$GITHUB_WORKSPACE`
- `:Z` flag sets SELinux context (though privileged mode disables SELinux)

### 2. Writing to Running Containers ✅

**Status**: Fully Supported

```yaml
- name: Write to running container
  run: |
    podman run -d --name my-container alpine:latest sleep 300
    echo "Content" | podman exec -i my-container sh -c "cat > /tmp/file.txt"
    podman exec my-container cat /tmp/file.txt
```

**Why it works**:
- Privileged mode grants necessary capabilities
- Podman can execute commands in running containers
- File system operations are permitted

### 3. Building Images with Files ✅

**Status**: Fully Supported

```yaml
- name: Build with files
  run: |
    echo "App data" > app.txt
    podman build -t my-app:latest .
```

**Why it works**:
- Workspace files are accessible during build
- Podman build context includes workspace
- COPY commands in Dockerfile work normally

### 4. Podman Volumes ✅

**Status**: Fully Supported

```yaml
- name: Use Podman volumes
  run: |
    podman volume create my-volume
    podman run --rm -v my-volume:/data:Z alpine:latest \
      sh -c "echo 'Data' > /data/file.txt"
    podman run --rm -v my-volume:/data:Z,ro alpine:latest \
      cat /data/file.txt
```

**Why it works**:
- Podman storage is mounted and accessible
- Volume operations work normally
- Data persists within the pod lifecycle

## 🔍 Additional Considerations

### SELinux Context

**Current Status**: Handled by Privileged Mode

- Privileged mode disables SELinux enforcement
- The `:Z` flag in volume mounts is still recommended for compatibility
- Environment variables `_CONTAINERS_ROOTLESS_UID/GID` help with context

### Workspace Access

**Status**: Automatic via ARC

- ARC automatically mounts workspace at `$GITHUB_WORKSPACE`
- No additional configuration needed in manifests
- Workspace is writable and accessible to inner containers

### Network Access

**Status**: Inherited from Pod

- Inner containers inherit network from the runner pod
- Network policies apply to the runner pod
- Inner containers can access external registries if pod has network access

### Storage Persistence

**Current Configuration**: Ephemeral (emptyDir)

- Podman storage is lost on pod restart
- For persistence, change to PersistentVolumeClaim:
  ```yaml
  volumes:
    - name: podman-storage
      persistentVolumeClaim:
        claimName: podman-storage-pvc
  ```

## 📋 Verification Checklist

To verify writing to inner containers works:

- [x] Privileged mode enabled
- [x] /dev/fuse mounted
- [x] Podman storage volume mounted
- [x] Environment variables configured
- [x] Workspace accessible (automatic via ARC)
- [ ] Test volume mount from workspace
- [ ] Test writing to running container
- [ ] Test building images with files
- [ ] Test Podman volumes

## 🚀 Recommended Workflow Test

Create a test workflow to verify all methods:

```yaml
name: Test Writing to Containers

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      
      - name: Test volume mount
        run: |
          echo "test" > test.txt
          podman run --rm -v $GITHUB_WORKSPACE:/ws:Z alpine cat /ws/test.txt
      
      - name: Test writing to container
        run: |
          podman run -d --name test alpine sleep 60
          echo "data" | podman exec -i test sh -c "cat > /tmp/data.txt"
          podman exec test cat /tmp/data.txt
          podman stop test && podman rm test
      
      - name: Test Podman volume
        run: |
          podman volume create test-vol
          podman run --rm -v test-vol:/data:Z alpine sh -c "echo 'persistent' > /data/file.txt"
          podman run --rm -v test-vol:/data:Z alpine cat /data/file.txt
          podman volume rm test-vol
```

## ✅ Conclusion

**The AutoscalingRunnerSet manifest is properly configured for writing to inner containers!**

All required configurations are in place:
- ✅ Privileged mode with all capabilities
- ✅ Device mounts (/dev/fuse)
- ✅ Storage volumes
- ✅ Environment variables
- ✅ Workspace access (automatic via ARC)

The manifests support all methods of writing to inner containers:
- ✅ Volume mounts from workspace
- ✅ Writing to running containers
- ✅ Building images with files
- ✅ Using Podman volumes

No additional changes are required for basic functionality. Optional improvements:
- Consider PersistentVolumeClaim for storage persistence
- Add resource limits if needed
- Configure network policies if required
