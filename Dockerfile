# Ubuntu 24.04 Development Shell
# Purpose: Clean Ubuntu environment with SSH, Docker CLI, and Docker Compose v2
# Architecture: amd64 (Synology DS220+ compatible)

FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base system packages
RUN apt-get update && \
    apt-get install -y \
        openssh-server \
        sudo \
        curl \
        ca-certificates \
        gnupg \
        lsb-release \
        git \
        vim \
        nano \
        wget \
        iputils-ping \
        net-tools \
        htop \
        socat \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Add Docker's official GPG key and repository
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CLI and Docker Compose v2
RUN apt-get update && \
    apt-get install -y \
        docker-ce-cli \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH for key-only authentication
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config

# Create initial user structure (will be configured at runtime by entrypoint)
# The entrypoint will handle:
# - User creation with correct UID/GID
# - Group alignment for docker socket
# - SSH key permissions
# This is just a placeholder to ensure the entrypoint can work
RUN groupadd -g 100 users || true

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose SSH port
EXPOSE 22

# Start SSH daemon via entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
