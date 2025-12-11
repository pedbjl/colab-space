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
    usermod -aG sudo ${USER_NAME}

# Install Miniconda3
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean --all -y && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Configure bashrc for user
RUN echo "export PATH=/opt/conda/bin:\$PATH" >> /home/${USER_NAME}/.bashrc && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.bashrc && \
    mkdir -p /home/${USER_NAME}/.ssh && \
    chmod 700 /home/${USER_NAME}/.ssh && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh

# Generate SSH key pair during build (store in /root/.ssh to avoid volume mount override)
RUN mkdir -p /root/.ssh && \
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/docker-key.pem -N "" -C "docker-generated-key" && \
    chmod 600 /root/.ssh/docker-key.pem && \
    chmod 644 /root/.ssh/docker-key.pem.pub && \
    # Add public key to authorized_keys
    cat /root/.ssh/docker-key.pem.pub >> /home/${USER_NAME}/.ssh/authorized_keys && \
    chmod 600 /home/${USER_NAME}/.ssh/authorized_keys && \
    chown ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.ssh/authorized_keys && \
    echo "SSH key pair generated during build at /root/.ssh/docker-key.pem"

# Create startup script to setup SSH keys and configuration
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
USER_NAME="${USER_NAME:-researcher}"\n\
SSH_KEYS_DIR="/etc/ssh/keys"\n\
AUTHORIZED_KEYS="/home/${USER_NAME}/.ssh/authorized_keys"\n\
BUILT_IN_KEY="/root/.ssh/docker-key.pem"\n\
SSH_CONFIG="/etc/ssh/sshd_config"\n\
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
# Initialize authorized_keys file\n\
> "$AUTHORIZED_KEYS"\n\
\n\
# Always add built-in key if it exists (from build time)\n\
if [ -f "$BUILT_IN_KEY" ]; then\n\
    echo "Adding built-in SSH key to authorized_keys..."\n\
    ssh-keygen -y -f "$BUILT_IN_KEY" >> "$AUTHORIZED_KEYS" 2>/dev/null || true\n\
    # Copy built-in key to mounted volume if it is writable and key doesn't exist\n\
    if [ -w "/etc/ssh/keys" ] 2>/dev/null; then\n\
        if [ ! -f "/etc/ssh/keys/docker-key.pem" ]; then\n\
            echo "Copying built-in SSH key to mounted volume..."\n\
            cp "$BUILT_IN_KEY" /etc/ssh/keys/docker-key.pem 2>/dev/null || true\n\
            cp "$BUILT_IN_KEY.pub" /etc/ssh/keys/docker-key.pem.pub 2>/dev/null || true\n\
            chmod 600 /etc/ssh/keys/docker-key.pem 2>/dev/null || true\n\
            chmod 644 /etc/ssh/keys/docker-key.pem.pub 2>/dev/null || true\n\
            echo "Built-in SSH key copied to $SSH_KEYS_DIR"\n\
        else\n\
            echo "SSH key already exists in $SSH_KEYS_DIR"\n\
        fi\n\
    else\n\
        echo "Warning: /etc/ssh/keys is not writable, cannot copy built-in key"\n\
    fi\n\
fi\n\
\n\
# Process external .pem files and add to authorized_keys\n\
if [ -d "$SSH_KEYS_DIR" ] && [ "$(ls -A $SSH_KEYS_DIR/*.pem 2>/dev/null)" ]; then\n\
    echo "Processing external SSH keys from $SSH_KEYS_DIR..."\n\
    for key_file in $SSH_KEYS_DIR/*.pem; do\n\
        # Skip built-in key files\n\
        if [[ "$(basename $key_file)" == "docker-key.pem" ]] || [[ "$(basename $key_file)" == "docker-key.pem.built" ]]; then\n\
            continue\n\
        fi\n\
        if [ -f "$key_file" ]; then\n\
            echo "Adding key: $(basename $key_file)"\n\
            # Extract public key from private key if it is a private key\n\
            if grep -q "BEGIN.*PRIVATE KEY" "$key_file"; then\n\
                ssh-keygen -y -f "$key_file" >> "$AUTHORIZED_KEYS" 2>/dev/null || true\n\
            else\n\
                # If it is already a public key, just append it\n\
                cat "$key_file" >> "$AUTHORIZED_KEYS"\n\
            fi\n\
        fi\n\
    done\n\
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

