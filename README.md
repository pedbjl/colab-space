# Collaborative Research Platform

A secure, GPU-enabled Docker-based platform designed for collaborative research and development. This platform provides a standardized environment for researchers to work together on data science, machine learning, and scientific computing projects with seamless SSH access and GPU acceleration support.

## 🎯 Overview

This platform creates an isolated, reproducible research environment that can be easily shared among team members. It combines the power of CUDA-enabled GPU computing with secure SSH access, making it ideal for:

- **Machine Learning Research**: Train and experiment with deep learning models
- **Data Science Collaboration**: Share computational resources and code
- **Scientific Computing**: Run GPU-accelerated simulations and analyses
- **Team Projects**: Provide consistent development environments across team members

## ✨ Features

### Core Capabilities
- **🐍 Python 3 Environment**: Pre-configured Python development environment
- **🚀 GPU Acceleration**: Full NVIDIA CUDA support for GPU-accelerated computing
- **📦 Miniconda3**: Pre-installed Conda package manager for easy dependency management
- **🔐 Secure SSH Access**: Key-based authentication with password and root login disabled
- **🌐 Remote Access**: Access your research environment from anywhere via SSH
- **📁 Shared Workspace**: Persistent workspace directory shared between host and container

### Security Features
- **SSH Key Authentication**: Automatic SSH key generation during build
- **Password Authentication Disabled by Default**: Enhanced security with key-only access (configurable)
- **Root Login Disabled by Default**: Prevents unauthorized root access (configurable)
- **Isolated Environment**: Containerized environment for safe experimentation
- **Configurable Security Settings**: Control root login and password authentication via environment variables

### Developer Experience
- **Easy Setup**: One-command deployment with Docker Compose
- **Customizable Configuration**: Environment-based configuration via `.env` file
- **Persistent Storage**: Workspace directory persists across container restarts
- **Korean Mirror Support**: Optimized package downloads using Korean Ubuntu mirrors

## 📋 Requirements

### System Requirements
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **NVIDIA GPU** (optional): For GPU acceleration
- **NVIDIA Container Toolkit**: Required for GPU support

### Operating System
- Linux (Ubuntu 20.04+ recommended)
- macOS (with Docker Desktop)
- Windows (with WSL2 and Docker Desktop)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd researcher
```

### 2. Configure Environment

Create a `.env` file from the example (if available) or create one manually:

```bash
# Create .env file
cat > .env << EOF
SSH_PORT=22
USER_NAME=researcher
USER_PASSWORD=your_secure_password
ROOT_PASSWORD=your_secure_root_password
ALLOW_ROOT_LOGIN=no
ALLOW_PASSWORD_AUTH=no
EOF
```

**Security Note**: The default settings (`ALLOW_ROOT_LOGIN=no` and `ALLOW_PASSWORD_AUTH=no`) provide the highest security by disabling root login and password authentication. Only SSH key-based authentication is enabled. You can change these settings if needed, but it's not recommended for production use.

**Security Note**: Generate secure passwords using:

```bash
# Generate secure passwords
openssl rand -base64 24 | tr -d "=+/" | cut -c1-32
```

### 3. Install NVIDIA Container Toolkit (For GPU Support)

If you need GPU support, install the NVIDIA Container Toolkit:

```bash
# Add NVIDIA repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/amd64 | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install and configure
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 4. Build and Start the Platform

```bash
# Build the image and start the container
docker compose up -d --build
```

### 5. Access Your Research Environment

#### Using Auto-Generated SSH Key

The platform automatically generates an SSH key during build. The key is automatically copied to the `ssh-keys/` directory when the container starts.

**Connect using the auto-generated key:**

```bash
ssh -i ssh-keys/docker-key.pem -p 22 researcher@localhost
```

Or if you've customized the SSH port in `.env`:

```bash
ssh -i ssh-keys/docker-key.pem -p ${SSH_PORT} researcher@localhost
```

**Note**: If the key is not in `ssh-keys/`, you can extract it manually:

```bash
# Extract the generated SSH key from container
./extract-ssh-key.sh

# Then connect
ssh -i ssh-keys/docker-key.pem -p 22 researcher@localhost
```

#### Using Your Own SSH Key

1. Place your `.pem` SSH key file in the `ssh-keys/` directory:

```bash
cp your-key.pem ssh-keys/
```

2. Restart the container:

```bash
docker compose restart python-gpu
```

3. Connect using your key:

```bash
ssh -i ssh-keys/your-key.pem -p 22 researcher@localhost
```

Or with custom port:

```bash
ssh -i ssh-keys/your-key.pem -p ${SSH_PORT} researcher@localhost
```

## 📖 Detailed Usage

### Configuration Options

All configuration is managed through the `.env` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_PORT` | SSH port mapping (host:container) | `22` |
| `USER_NAME` | Default user name | `researcher` |
| `USER_PASSWORD` | User password | `researcher` |
| `ROOT_PASSWORD` | Root password | `root` |
| `ALLOW_ROOT_LOGIN` | Allow root login via SSH (`yes`/`no`) | `no` |
| `ALLOW_PASSWORD_AUTH` | Allow password authentication (`yes`/`no`) | `no` |

**Security Note**: By default, both root login and password authentication are **disabled** for enhanced security. Only SSH key-based authentication is enabled. You can enable these features by setting the respective environment variables to `yes`, but this is **not recommended** for production use.

### Container Management

```bash
# Start the platform
docker compose up -d

# Stop the platform
docker compose down

# View logs
docker compose logs -f

# Restart the platform
docker compose restart

# Rebuild after changes
docker compose up -d --build
```

### Direct Container Access

```bash
# Access container shell
docker compose exec python-gpu bash

# Access as specific user
docker compose exec -u researcher python-gpu bash
```

### Workspace Directory

The `workspace/` directory is shared between your host and the container:

- **Host Path**: `./workspace`
- **Container Path**: `/home/researcher/workspace`

Files placed in this directory persist across container restarts and are accessible from both the host and container.

### Python Environment

Miniconda3 is pre-installed and configured:

```bash
# Activate conda (already in PATH)
conda --version

# Create a new environment
conda create -n myproject python=3.11

# Install packages
conda install numpy pandas matplotlib
# or
pip install tensorflow torch
```

### GPU Usage

If NVIDIA GPU is available and configured:

```python
# Check GPU availability
import torch
print(torch.cuda.is_available())

# Use GPU in PyTorch
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
```

## 🔒 Security Best Practices

### Default Security Settings

By default, this platform implements strict security measures:

- **Root Login Disabled**: Root access via SSH is disabled by default (`ALLOW_ROOT_LOGIN=no`)
- **Password Authentication Disabled**: Password-based SSH authentication is disabled by default (`ALLOW_PASSWORD_AUTH=no`)
- **Key-Based Authentication Only**: Only SSH key-based authentication is enabled

These settings provide enhanced security and are recommended for production use.

### Configuring Security Settings

You can modify security settings via environment variables in your `.env` file:

```bash
# Enable root login (NOT RECOMMENDED)
ALLOW_ROOT_LOGIN=yes

# Enable password authentication (NOT RECOMMENDED)
ALLOW_PASSWORD_AUTH=yes
```

**⚠️ Warning**: Enabling root login or password authentication reduces security. Only enable these features if absolutely necessary and ensure you use strong passwords.

### General Security Recommendations

1. **Use SSH Keys**: Always use SSH key authentication instead of passwords
2. **Secure Passwords**: Generate strong passwords even if not used for SSH
3. **Firewall Rules**: Restrict SSH port access to trusted IPs if exposed
4. **Regular Updates**: Keep the base image and packages updated
5. **Key Management**: Store SSH keys securely and don't commit them to version control
6. **Keep Defaults**: Unless you have a specific need, keep `ALLOW_ROOT_LOGIN=no` and `ALLOW_PASSWORD_AUTH=no`

## 📁 Project Structure

```
researcher/
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Docker Compose configuration
├── .env                    # Environment configuration (not in git)
├── .gitignore             # Git ignore rules
├── README.md              # This file
├── extract-ssh-key.sh    # Script to extract SSH keys
├── ssh-keys/              # SSH key directory (keys not in git)
│   └── README.txt        # Instructions for SSH keys
└── workspace/             # Shared workspace directory
```

## 🛠️ Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs

# Check if port is already in use
netstat -tuln | grep ${SSH_PORT}

# Verify Docker is running
sudo systemctl status docker
```

### GPU Not Available

```bash
# Verify NVIDIA drivers
nvidia-smi

# Check NVIDIA Container Toolkit
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Verify container has GPU access
docker compose exec python-gpu nvidia-smi
```

### SSH Connection Issues

```bash
# Verify SSH service is running
docker compose exec python-gpu systemctl status ssh

# Check SSH configuration
docker compose exec python-gpu cat /etc/ssh/sshd_config | grep -E "PasswordAuthentication|PermitRootLogin|PubkeyAuthentication"

# Verify authorized_keys
docker compose exec python-gpu cat /home/researcher/.ssh/authorized_keys
```

### Permission Issues

```bash
# Fix workspace permissions
sudo chown -R $USER:$USER workspace/

# Fix SSH key permissions
chmod 600 ssh-keys/*.pem
```

## 🤝 Contributing

This is a collaborative research platform. Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

[Specify your license here]

## 🙏 Acknowledgments

- NVIDIA for CUDA support
- Docker team for containerization technology
- Open source community for various tools and libraries

## 📧 Support

For issues, questions, or contributions, please open an issue on the repository.

---

**Happy Researching! 🚀**
