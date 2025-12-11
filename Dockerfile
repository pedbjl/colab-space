# Use CUDA-based Python image
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# Build arguments
ARG USER_NAME=researcher
ARG USER_PASSWORD=researcher
ARG ROOT_PASSWORD=root

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV MINICONDA_VERSION=latest
ENV PATH=/opt/conda/bin:$PATH
ENV USER_NAME=${USER_NAME}

# Change Ubuntu repository to Korean mirror
RUN sed -i 's|archive.ubuntu.com|kr.archive.ubuntu.com|g' /etc/apt/sources.list && \
    sed -i 's|security.ubuntu.com|kr.archive.ubuntu.com|g' /etc/apt/sources.list

# Install and update base packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    openssh-server \
    sudo \
    wget \
    curl \
    vim \
    git \
    zip \
    && rm -rf /var/lib/apt/lists/*

# SSH configuration (basic setup, detailed config in startup script)
RUN mkdir /var/run/sshd && \
    mkdir -p /etc/ssh/keys && \
    # Enable public key authentication by default
    sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    # Disable PAM
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# Create user and set password
RUN useradd -m -s /bin/bash ${USER_NAME} && \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd && \
    usermod -aG sudo ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME}

# Install Miniconda3
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean --all -y && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Configure bashrc for user and initialize conda
RUN mkdir -p /home/${USER_NAME}/.ssh && \
    chmod 700 /home/${USER_NAME}/.ssh && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh && \
    echo "" >> /home/${USER_NAME}/.bashrc && \
    echo "# >>> conda initialize >>>" >> /home/${USER_NAME}/.bashrc && \
    echo "# !! Contents within this block are managed by 'conda init' !!" >> /home/${USER_NAME}/.bashrc && \
    echo "__conda_setup=\"\$('/opt/conda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)\"" >> /home/${USER_NAME}/.bashrc && \
    echo "if [ \$? -eq 0 ]; then" >> /home/${USER_NAME}/.bashrc && \
    echo "    eval \"\$__conda_setup\"" >> /home/${USER_NAME}/.bashrc && \
    echo "else" >> /home/${USER_NAME}/.bashrc && \
    echo "    if [ -f \"/opt/conda/etc/profile.d/conda.sh\" ]; then" >> /home/${USER_NAME}/.bashrc && \
    echo "        . \"/opt/conda/etc/profile.d/conda.sh\"" >> /home/${USER_NAME}/.bashrc && \
    echo "    else" >> /home/${USER_NAME}/.bashrc && \
    echo "        export PATH=\"/opt/conda/bin:\$PATH\"" >> /home/${USER_NAME}/.bashrc && \
    echo "    fi" >> /home/${USER_NAME}/.bashrc && \
    echo "fi" >> /home/${USER_NAME}/.bashrc && \
    echo "unset __conda_setup" >> /home/${USER_NAME}/.bashrc && \
    echo "# <<< conda initialize <<<" >> /home/${USER_NAME}/.bashrc && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bashrc

# Create .ssh directory for root (keys will be generated at runtime, not during build)
RUN mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Create startup script to setup SSH keys and configuration
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
USER_NAME="${USER_NAME:-researcher}"\n\
AUTHORIZED_KEYS="/home/${USER_NAME}/.ssh/authorized_keys"\n\
BUILT_IN_KEY="/root/.ssh/docker-key.pem"\n\
SSH_CONFIG="/etc/ssh/sshd_config"\n\
WORKSPACE_DIR="/home/${USER_NAME}/workspace"\n\
SSH_KEYS_OUTPUT_DIR="/opt/ssh-keys-output"\n\
\n\
# Configure SSH settings from environment variables\n\
ALLOW_ROOT_LOGIN="${ALLOW_ROOT_LOGIN:-no}"\n\
ALLOW_PASSWORD_AUTH="${ALLOW_PASSWORD_AUTH:-no}"\n\
\n\
echo "Configuring SSH settings..."\n\
echo "  Allow root login: $ALLOW_ROOT_LOGIN"\n\
echo "  Allow password authentication: $ALLOW_PASSWORD_AUTH"\n\
\n\
# Configure root login\n\
if [ "$ALLOW_ROOT_LOGIN" = "yes" ]; then\n\
    sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" "$SSH_CONFIG"\n\
    sed -i "s/^PermitRootLogin.*/PermitRootLogin yes/" "$SSH_CONFIG"\n\
else\n\
    sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"\n\
    sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"\n\
fi\n\
\n\
# Configure password authentication\n\
if [ "$ALLOW_PASSWORD_AUTH" = "yes" ]; then\n\
    sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" "$SSH_CONFIG"\n\
    sed -i "s/^PasswordAuthentication.*/PasswordAuthentication yes/" "$SSH_CONFIG"\n\
else\n\
    sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/" "$SSH_CONFIG"\n\
    sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" "$SSH_CONFIG"\n\
fi\n\
\n\
# Create .ssh directory if it does not exist\n\
mkdir -p /home/${USER_NAME}/.ssh\n\
chmod 700 /home/${USER_NAME}/.ssh\n\
\n\
# Get user UID and GID\n\
USER_UID=$(id -u ${USER_NAME} 2>/dev/null || getent passwd ${USER_NAME} | cut -d: -f3)\n\
USER_GID=$(id -g ${USER_NAME} 2>/dev/null || getent passwd ${USER_NAME} | cut -d: -f4)\n\
\n\
# Create workspace directory and set ownership to user\n\
mkdir -p "$WORKSPACE_DIR"\n\
if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then\n\
    chown -R ${USER_UID}:${USER_GID} "$WORKSPACE_DIR" 2>/dev/null || chown -R ${USER_NAME}:${USER_NAME} "$WORKSPACE_DIR"\n\
    chmod 755 "$WORKSPACE_DIR"\n\
    echo "Workspace directory ownership set to ${USER_NAME} (UID: $USER_UID, GID: $USER_GID)"\n\
else\n\
    chown -R ${USER_NAME}:${USER_NAME} "$WORKSPACE_DIR"\n\
    chmod 755 "$WORKSPACE_DIR"\n\
    echo "Workspace directory ownership set to ${USER_NAME}"\n\
fi\n\
\n\
# Create ssh-keys-output directory and set ownership to user\n\
mkdir -p "$SSH_KEYS_OUTPUT_DIR"\n\
if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then\n\
    chown -R ${USER_UID}:${USER_GID} "$SSH_KEYS_OUTPUT_DIR" 2>/dev/null || chown -R ${USER_NAME}:${USER_NAME} "$SSH_KEYS_OUTPUT_DIR"\n\
    chmod 755 "$SSH_KEYS_OUTPUT_DIR"\n\
    echo "SSH keys output directory ownership set to ${USER_NAME} (UID: $USER_UID, GID: $USER_GID)"\n\
else\n\
    chown -R ${USER_NAME}:${USER_NAME} "$SSH_KEYS_OUTPUT_DIR"\n\
    chmod 755 "$SSH_KEYS_OUTPUT_DIR"\n\
    echo "SSH keys output directory ownership set to ${USER_NAME}"\n\
fi\n\
\n\
# Initialize authorized_keys file\n\
> "$AUTHORIZED_KEYS"\n\
\n\
# Check if key already exists\n\
KEY_GENERATED=false\n\
if [ -f "$BUILT_IN_KEY" ] && [ -f "$BUILT_IN_KEY.pub" ]; then\n\
    echo "SSH key pair already exists at $BUILT_IN_KEY, skipping generation"\n\
    echo "Using existing key pair"\n\
else\n\
    echo "SSH key pair not found, generating new key pair..."\n\
    mkdir -p /root/.ssh\n\
    ssh-keygen -t rsa -b 4096 -f "$BUILT_IN_KEY" -N "" -C "docker-generated-key"\n\
    chmod 600 "$BUILT_IN_KEY"\n\
    chmod 644 "$BUILT_IN_KEY.pub"\n\
    KEY_GENERATED=true\n\
    echo "SSH key pair generated at $BUILT_IN_KEY"\n\
fi\n\
\n\
# Always add built-in key to authorized_keys if it exists\n\
if [ -f "$BUILT_IN_KEY" ]; then\n\
    echo "Adding SSH key to authorized_keys..."\n\
    ssh-keygen -y -f "$BUILT_IN_KEY" >> "$AUTHORIZED_KEYS" 2>/dev/null || true\n\
    \n\
    # Create zip file with SSH keys ONLY if key was just generated (not if it already existed)\n\
    # Try to create in output directory first, fallback to workspace if not available\n\
    ZIP_DIR=""\n\
    if [ -d "$SSH_KEYS_OUTPUT_DIR" ] && [ -w "$SSH_KEYS_OUTPUT_DIR" ]; then\n\
        ZIP_DIR="$SSH_KEYS_OUTPUT_DIR"\n\
    elif [ -d "$WORKSPACE_DIR" ] && [ -w "$WORKSPACE_DIR" ]; then\n\
        ZIP_DIR="$WORKSPACE_DIR"\n\
    fi\n\
    \n\
    if [ "$KEY_GENERATED" = "true" ] && [ -n "$ZIP_DIR" ]; then\n\
        echo "Creating SSH key zip file for download..."\n\
        ZIP_FILE="$ZIP_DIR/ssh-keys-$(date +%Y%m%d-%H%M%S).zip"\n\
        cd /tmp\n\
        cp "$BUILT_IN_KEY" docker-key.pem\n\
        cp "$BUILT_IN_KEY.pub" docker-key.pem.pub\n\
        chmod 644 docker-key.pem docker-key.pem.pub\n\
        zip -q "$ZIP_FILE" docker-key.pem docker-key.pem.pub\n\
        rm -f docker-key.pem docker-key.pem.pub\n\
        # Set ownership using UID/GID if available\n\
        if [ -n "$USER_UID" ] && [ -n "$USER_GID" ]; then\n\
            chown ${USER_UID}:${USER_GID} "$ZIP_FILE" 2>/dev/null || chown ${USER_NAME}:${USER_NAME} "$ZIP_FILE"\n\
        else\n\
            chown ${USER_NAME}:${USER_NAME} "$ZIP_FILE"\n\
        fi\n\
        chmod 644 "$ZIP_FILE"\n\
        echo "SSH keys packaged in: $ZIP_FILE"\n\
        echo "You can download this file from the workspace directory."\n\
    else\n\
        if [ "$KEY_GENERATED" = "false" ]; then\n\
            echo "Using existing SSH key - no zip file will be created"\n\
        fi\n\
    fi\n\
fi\n\
\n\
# Set proper permissions for authorized_keys\n\
if [ -s "$AUTHORIZED_KEYS" ]; then\n\
    chmod 600 "$AUTHORIZED_KEYS"\n\
    chown ${USER_NAME}:${USER_NAME} "$AUTHORIZED_KEYS"\n\
    echo "SSH keys configured in $AUTHORIZED_KEYS"\n\
    echo "Total keys: $(wc -l < "$AUTHORIZED_KEYS")"\n\
else\n\
    echo "Warning: No SSH keys found in authorized_keys"\n\
    if [ "$ALLOW_PASSWORD_AUTH" != "yes" ]; then\n\
        echo "SSH key-based authentication will not be available"\n\
    fi\n\
fi\n\
\n\
# Start SSH service\n\
echo "Starting SSH service..."\n\
exec /usr/sbin/sshd -D\n\
' > /usr/local/bin/start-ssh.sh && \
    chmod +x /usr/local/bin/start-ssh.sh

# Expose SSH port
EXPOSE 22

# Start SSH service with key setup
CMD ["/usr/local/bin/start-ssh.sh"]

