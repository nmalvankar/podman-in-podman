# Writing to Inner Containers with Podman

Yes, you can write to containers created by Podman running inside the GitHub Actions runner container. This guide explains the different methods and best practices.

## Methods for Writing to Inner Containers

### 1. Volume Mounts (Recommended)

Mount the GitHub Actions workspace (or any directory) into the inner container:

```yaml
- name: Write via volume mount
  run: |
    # Create file in workspace
    echo "Hello" > workspace-file.txt
    
    # Mount workspace into container
    podman run --rm \
      -v $GITHUB_WORKSPACE:/workspace:Z \
      alpine:latest \
      sh -c "cat /workspace/workspace-file.txt"
```

**Key Points:**
- `$GITHUB_WORKSPACE` is the default working directory in GitHub Actions
- `:Z` flag sets SELinux context (required on RHEL-based systems)
- Files written in workspace are accessible in container
- Files written in container are accessible in workspace

### 2. Using `podman exec` to Write Files

Write files to a running container:

```yaml
- name: Write to running container
  run: |
    # Start container
    podman run -d --name my-container alpine:latest sleep 300
    
    # Write file via exec
    echo "Content" | podman exec -i my-container sh -c "cat > /tmp/file.txt"
    
    # Verify
    podman exec my-container cat /tmp/file.txt
    
    # Cleanup
    podman stop my-container
    podman rm my-container
```

### 3. Building Images with Files

Include files from workspace during image build:

```yaml
- name: Build with workspace files
  run: |
    # Create file
    echo "App data" > app.txt
    
    # Build image (Dockerfile COPY will include app.txt)
    podman build -t my-app:latest .
```

**Dockerfile:**
```dockerfile
FROM alpine:latest
COPY app.txt /app/app.txt
RUN cat /app/app.txt
```

### 4. Using Podman Volumes

Create persistent volumes for data sharing:

```yaml
- name: Use Podman volumes
  run: |
    # Create volume
    podman volume create my-volume
    
    # Write to volume
    podman run --rm \
      -v my-volume:/data:Z \
      alpine:latest \
      sh -c "echo 'Data' > /data/file.txt"
    
    # Read from volume
    podman run --rm \
      -v my-volume:/data:Z,ro \
      alpine:latest \
      cat /data/file.txt
    
    # Cleanup
    podman volume rm my-volume
```

## Important Considerations

### SELinux Context (`:Z` flag)

On RHEL-based systems (like this runner image), you **must** use the `:Z` flag for volume mounts:

```bash
-v $GITHUB_WORKSPACE:/workspace:Z
```

This sets the correct SELinux context for the mounted volume.

### Permissions

When writing to containers:

1. **Root vs Non-Root**: 
   - In ARC with `runAsUser: 0`, you're running as root
   - Files created will be owned by root
   - Use `chown` if you need different ownership

2. **Workspace Permissions**:
   - GitHub Actions workspace is typically writable
   - Files created in workspace are accessible to subsequent steps

3. **Container Filesystem**:
   - Containers have their own filesystem
   - Changes are ephemeral unless using volumes
   - Use `--rm` flag to auto-remove containers after use

### Volume Mount Options

```bash
# Read-write mount
-v /host/path:/container/path:Z

# Read-only mount
-v /host/path:/container/path:Z,ro

# Multiple mounts
-v /path1:/path1:Z -v /path2:/path2:Z
```

## Common Use Cases

### 1. Building Applications

```yaml
- name: Build application in container
  run: |
    podman run --rm \
      -v $GITHUB_WORKSPACE:/workspace:Z \
      -w /workspace \
      golang:latest \
      go build -o app ./cmd
```

### 2. Running Tests

```yaml
- name: Run tests in container
  run: |
    podman run --rm \
      -v $GITHUB_WORKSPACE:/workspace:Z \
      -w /workspace \
      node:latest \
      npm test
```

### 3. Processing Files

```yaml
- name: Process files
  run: |
    # Create input file
    echo "input data" > input.txt
    
    # Process in container
    podman run --rm \
      -v $GITHUB_WORKSPACE:/workspace:Z \
      python:latest \
      python -c "
        with open('/workspace/input.txt') as f:
          data = f.read()
        with open('/workspace/output.txt', 'w') as f:
          f.write(data.upper())
      "
    
    # Use output
    cat output.txt
```

### 4. Building Container Images

```yaml
- name: Build and push image
  run: |
    # Build image (includes workspace files via COPY in Dockerfile)
    podman build -t my-registry/my-app:$GITHUB_SHA .
    
    # Tag and push
    podman tag my-registry/my-app:$GITHUB_SHA my-registry/my-app:latest
    podman push my-registry/my-app:$GITHUB_SHA
    podman push my-registry/my-app:latest
```

## Troubleshooting

### Permission Denied Errors

**Problem**: Cannot write to mounted volume

**Solution**:
```bash
# Ensure :Z flag is used
-v $GITHUB_WORKSPACE:/workspace:Z

# Check permissions
ls -la $GITHUB_WORKSPACE

# If running as root, adjust ownership
chown -R root:root $GITHUB_WORKSPACE
```

### SELinux Errors

**Problem**: SELinux blocking access

**Solution**:
- Always use `:Z` flag on volume mounts
- In ARC, privileged mode should handle this automatically

### Files Not Persisting

**Problem**: Files written to container disappear

**Solution**:
- Use volume mounts for persistence
- Don't use `--rm` if you need to keep container
- Use Podman volumes for data that needs to persist

## Best Practices

1. **Use Volume Mounts**: Prefer mounting workspace over copying files
2. **Clean Up**: Always clean up containers and volumes
3. **Use `:Z` Flag**: Required on RHEL-based systems
4. **Read-Only When Possible**: Use `:ro` for read-only mounts
5. **Workspace Path**: Use `$GITHUB_WORKSPACE` for consistency
6. **Error Handling**: Check if files exist before using them

## Example: Complete Workflow

See `.github/workflows/example-write-to-container.yml` for a complete example demonstrating all methods.

## Summary

✅ **Yes, you can write to inner containers!**

- Use volume mounts to share files between workspace and containers
- Use `podman exec` to write files to running containers
- Include files during image build with COPY in Dockerfile
- Use Podman volumes for persistent data
- Always use `:Z` flag on RHEL-based systems
- Files written in workspace are accessible in containers and vice versa
