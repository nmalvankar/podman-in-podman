# GitHub Actions Runner Container Image
# This Containerfile creates a custom GitHub Actions runner image using Podman
#
# Compatibility:
# - Standalone mode: Runs as 'runner' user (non-root)
# - ARC mode: Can run as root (runAsUser: 0) when using privileged: true
# - The entrypoint script automatically detects and handles both modes

FROM registry.redhat.io/ubi9/ubi:latest

# Set environment variables
ENV RUNNER_VERSION=2.333.0
ENV RUNNER_USER=runner
ENV RUNNER_WORKDIR=/home/${RUNNER_USER}/actions-runner

# Install dependencies including Podman
RUN dnf update -y && dnf install -y \
    curl-minimal \
    wget \
    git \
    jq \
    unzip \
    tar \
    ca-certificates \
    sudo \
    gcc \
    gcc-c++ \
    make \
    podman \
    fuse-overlayfs \
    slirp4netns \
    && dnf clean all

# Create runner user with subuid/subgid mappings for rootless Podman
RUN useradd -m -s /bin/bash ${RUNNER_USER} && \
    echo "${RUNNER_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "${RUNNER_USER}:100000:65536" >> /etc/subuid && \
    echo "${RUNNER_USER}:100000:65536" >> /etc/subgid

# Create work directory with permissions for both root and runner user
# This allows the container to work in both privileged (root) and non-privileged modes
RUN mkdir -p ${RUNNER_WORKDIR} && \
    chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_WORKDIR} && \
    chmod 755 ${RUNNER_WORKDIR}

# Download and install GitHub Actions runner
RUN cd /tmp && \
    curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -C ${RUNNER_WORKDIR} && \
    chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_WORKDIR} && \
    rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown root:root /usr/local/bin/entrypoint.sh

# Note: USER is set to runner for standalone mode, but ARC can override with runAsUser: 0
# The entrypoint script handles both root and non-root execution
USER ${RUNNER_USER}

# Set working directory
WORKDIR ${RUNNER_WORKDIR}

# Expose port (if needed for services)
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
