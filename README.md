# ClawCMD Cyber Club - Initial Infrastructure Setup

Main deployment script for the club's main infrastructure.

## Overview

This is the primary deployment script for ClawCMD Cyber Club's main infrastructure. It provides a modular, reusable framework for initial infrastructure setup, specifically designed for:

- **First-time infrastructure setup** - When building new Proxmox infrastructure from scratch
- **Post-reset deployment** - After wiping/resetting Proxmox and need to rebuild
- **Basic remote access setup** - Deploys an Ubuntu LXC container with NetBird (VPN) and Cloudflare Tunnel for secure remote connectivity

This script automates the deployment of Ubuntu LXC containers on Proxmox VE with automated installation of NetBird and Cloudflare Tunnel services, establishing the foundation for remote access to the infrastructure.

## Project Structure

```
clawcmd-deploy/
├── install.sh                  # One-liner installation script (for GitHub)
├── initial-setup.sh           # Main initial infrastructure setup script
├── env.conf.example           # Configuration template
├── env.conf                   # Your configuration (create from example, gitignored)
├── scripts/
│   ├── common.sh              # Common functions library
│   ├── create-container.sh    # LXC container creation
│   ├── install-netbird.sh    # NetBird installation
│   ├── install-cloudflared.sh # Cloudflare Tunnel installation
│   ├── install-proxmox-tools.sh # Proxmox host tools installation
│   └── ui-selector.sh         # Interactive UI selection functions
└── README.md                  # This file
```

## When to Use This Script

This script is designed for **initial infrastructure setup** scenarios:

- ✅ Setting up a brand new Proxmox server
- ✅ After wiping/resetting Proxmox infrastructure
- ✅ First-time deployment of basic remote access services
- ✅ Establishing secure remote connectivity foundation

**Note:** This is not for routine container deployments, but specifically for the initial setup of remote access infrastructure.

## Quick Start

### Option 1: One-Liner Installation from GitHub (Recommended)

Simply run this command on your Proxmox host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/clawcmd-deploy/install.sh)"
```

**Note:** Replace `USERNAME/REPO` with your actual GitHub repository path.

This will:
1. Install essential tools (tmux, iftop, htop) on Proxmox host
2. Clone the repository to `/opt/clawcmd-deploy`
3. Automatically start the initial infrastructure setup with **interactive UI mode** (default)

The script will prompt you to choose:
- **Interactive mode**: Step-by-step configuration (default, recommended)
- **Config file mode**: Use existing configuration file

### Option 2: Manual Installation

```bash
cd /home/user/Desktop/infra/clawcmd-deploy
sudo ./initial-setup.sh -i
```

This will launch a step-by-step UI interface where you can:
- Select container ID, hostname, and resources
- Choose template from available options
- Select storage pool
- Configure NetBird and Cloudflare Tunnel

### Option 4: Configuration File Mode

1. **Copy the example configuration:**
   ```bash
   cp env.conf.example env.conf
   ```

2. **Edit the configuration file:**
   ```bash
   nano env.conf
   ```
   
   Configure at minimum:
   - `CT_ID`: Container ID (must be unique, default: 1000)
   - `CT_HOSTNAME`: Container hostname (default: netbirdlxc)
   - `NETBIRD_SETUP_KEY`: Your NetBird setup key
   - `CLOUDFLARED_TOKEN`: Your Cloudflare tunnel token
   - `CT_TEMPLATE`: Template name (leave empty for auto-detection)
   - `STORAGE_POOL`: Storage pool name (leave empty for auto-detection)
   - `INSTALL_PROXMOX_TOOLS`: Set to 1 to install tmux, iftop, htop (default: 1)

3. **Run the deployment:**
   ```bash
   sudo ./initial-setup.sh -c
   ```

## Configuration File

The configuration file (`env.conf`) supports the following options:

### Container Specifications
- `CT_ID`: Container ID (must be unique, default: 1000)
- `CT_HOSTNAME`: Container hostname (default: netbirdlxc)
- `CT_CPU`: Number of CPU cores (default: 2)
- `CT_RAM`: RAM in MiB (default: 1024)
- `CT_SWAP`: Swap in MiB (default: 1024)
- `CT_STORAGE`: Storage in GB (default: 8)

### Network Configuration
- `CT_BRIDGE`: Network bridge (default: vmbr0)
- `CT_NETWORK`: Network configuration (default: dhcp)
- `CT_UNPRIVILEGED`: Use unprivileged container (1) or privileged (0) (default: 1)

### NetBird Configuration
- `NETBIRD_ENABLED`: Enable NetBird installation (1) or disable (0) (default: 1)
- `NETBIRD_MANAGEMENT_URL`: NetBird management URL (optional)
- `NETBIRD_SETUP_KEY`: NetBird setup key (required if enabled)

### Cloudflare Tunnel Configuration
- `CLOUDFLARED_ENABLED`: Enable Cloudflared installation (1) or disable (0) (default: 1)
- `CLOUDFLARED_TOKEN`: Cloudflare tunnel token (required if enabled)

### Template Configuration
- `CT_OS`: Operating system type (default: ubuntu)
- `CT_VERSION`: OS version (default: 22)
- `CT_TEMPLATE`: Full template name (leave empty for auto-detection or UI selection)

### Storage Configuration
- `STORAGE_POOL`: Storage pool name (leave empty for auto-detection or UI selection)

### Optional Settings
- `CT_TAGS`: Base Proxmox tags (default: core-services). Tags are auto-generated:
  - Always includes: `core-services`
  - Adds `netbird` if NetBird is enabled
  - Adds `cloudflared` if Cloudflare Tunnel is enabled

## Usage Examples

### Default Behavior (Interactive UI Mode)
```bash
sudo ./initial-setup.sh
```
Launches a step-by-step UI interface. You'll be prompted to choose:
- **Interactive mode**: Step-by-step configuration (recommended)
- **Config file mode**: Use existing configuration file

### Explicit Interactive Mode
```bash
sudo ./initial-setup.sh -i
```
Same as default, explicitly enables interactive mode.

### Configuration File Mode
```bash
sudo ./initial-setup.sh -c
```
Uses `env.conf` for all settings (skips UI selection).

### Custom Configuration File
```bash
sudo ./initial-setup.sh -c /path/to/custom.conf
```
Uses a custom configuration file.

### Individual Scripts

You can also run individual scripts if needed:

```bash
# Create container only
sudo bash scripts/create-container.sh

# Install NetBird only (requires CT_ID in environment)
export CT_ID=100
export NETBIRD_SETUP_KEY=your-key
sudo bash scripts/install-netbird.sh

# Install Cloudflared only (requires CT_ID in environment)
export CT_ID=100
export CLOUDFLARED_TOKEN=your-token
sudo bash scripts/install-cloudflared.sh
```

## Requirements

- Proxmox VE 8.0+ or 9.0+
- Root access
- Ubuntu template available in Proxmox (will be auto-detected or can be selected via UI)
- Network connectivity
- `whiptail` package (for interactive UI mode): `apt-get install whiptail`

## Features

- **One-Liner Installation**: Install directly from GitHub with a single command
- **Proxmox Host Tools**: Automatically installs tmux, iftop, and htop on Proxmox host
- **Dual Mode Operation**: 
  - **Config File Mode**: Automated deployment using configuration file
  - **Interactive UI Mode**: Step-by-step UI interface using whiptail
- **Template Selection**: Automatic detection or UI-based selection of container templates
- **Storage Pool Selection**: Automatic detection or UI-based selection of storage pools
- **Modular Design**: Each component is a separate script for easy maintenance
- **Reusable**: Common functions library for shared utilities
- **Configurable**: All settings via configuration file or interactive UI
- **Error Handling**: Comprehensive error checking and logging
- **Extensible**: Easy to add new services or modify existing ones

## Extending for Other Services

To add support for additional services:

1. Create a new installation script in `scripts/` (e.g., `install-myservice.sh`)
2. Add configuration options to `env.conf.example`
3. Update `initial-setup.sh` to call your new script
4. Follow the pattern established in existing scripts

Example:
```bash
# In initial-setup.sh, after Cloudflared installation:
if [[ "${MYSERVICE_ENABLED:-0}" == "1" ]]; then
    log_info "=== Step 4: Installing MyService ==="
    bash "${SCRIPTS_DIR}/install-myservice.sh"
fi
```

## Troubleshooting

### Container Creation Fails
- Check if container ID is already in use: `pct list`
- Verify storage pool has enough space
- Ensure Proxmox templates are available

### NetBird Not Working
- Verify TUN device is configured: Check `/etc/pve/lxc/${CT_ID}.conf`
- Ensure setup key is correct
- Check NetBird status: `pct exec ${CT_ID} -- netbird status`

### Cloudflared Not Working
- Verify token is correct
- Check service status: `pct exec ${CT_ID} -- systemctl status cloudflared`
- View logs: `pct exec ${CT_ID} -- journalctl -u cloudflared`

## License

Part of the ClawCMD Cyber Club infrastructure management system.

## Support

For issues or questions, contact the ClawCMD Cyber Club infrastructure team.

