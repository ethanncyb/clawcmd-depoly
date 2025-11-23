# ClawCMD - Initial Infrastructure Setup

Automated deployment script for Proxmox VE LXC containers with NetBird VPN and Cloudflare Tunnel.

## Overview

ClawCMD is a modular deployment framework for Proxmox VE that automates the creation and configuration of LXC containers with essential remote access services. It provides a streamlined way to deploy infrastructure containers with:

- **NetBird VPN** - Secure mesh VPN for remote access
- **Cloudflare Tunnel** - Secure tunnel to Cloudflare network
- **Container Tools** - Pre-installed utilities (tmux, htop, iftop)

This script automates the deployment of Debian LXC containers on Proxmox VE with automated installation of services, establishing the foundation for secure remote connectivity.

## Project Structure

```
clawcmd-deploy/
├── install.sh                    # One-liner installation script (for GitHub)
├── initial-setup.sh              # Main deployment script
├── env.conf.example              # Configuration template
├── env.conf                      # Your configuration (create from example, gitignored)
├── scripts/
│   ├── common.sh                 # Common functions library
│   ├── create-container.sh       # LXC container creation
│   ├── install-netbird.sh        # NetBird installation
│   ├── install-cloudflared.sh    # Cloudflare Tunnel installation
│   ├── install-container-tools.sh # Container tools installation (tmux, htop, iftop)
│   ├── install-proxmox-tools.sh  # Proxmox host tools installation
│   └── ui-selector.sh            # Interactive UI selection functions
└── README.md                     # This file
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
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ethanncyb/clawcmd-depoly/refs/heads/main/install.sh)"
```

This will:
1. Install essential tools (tmux, iftop, htop) on Proxmox host
2. Clone the repository to `/opt/clawcmd-deploy`
3. Automatically start the initial infrastructure setup with **interactive UI mode** (default)

The script will prompt you to choose:
- **Quick Setup (Default)**: Uses default settings with minimal configuration
- **Config File Mode**: Use existing configuration file
- **Advanced/Interactive Mode**: Step-by-step configuration with full control

### Option 2: Manual Installation

```bash
cd /opt/clawcmd-deploy
sudo ./initial-setup.sh -i
```

This will launch a step-by-step UI interface where you can:
- Select container ID, hostname, and resources
- Choose template storage location (where templates are stored)
- Select container template (with automatic download if needed)
- Select container storage pool (where container disk will be saved)
- Choose services to install (NetBird, Cloudflare Tunnel, or both)
- Configure selected services

### Option 3: Configuration File Mode

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
- `CT_OS`: Operating system type (default: debian)
- `CT_VERSION`: OS version (default: 13)
- `CT_TEMPLATE`: Full template path (e.g., `local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst`)
  - Leave empty for auto-detection or UI selection
- `TEMPLATE_STORAGE`: Storage pool where templates are stored/downloaded (default: local)
  - This is where container templates are stored, separate from container storage

### Storage Configuration
- `STORAGE_POOL`: Storage pool where container disk will be saved (default: local-lvm)
  - This is where the container's root filesystem is stored, separate from template storage

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
- Debian template available in Proxmox (will be auto-detected, downloaded automatically, or can be selected via UI)
- Network connectivity
- `whiptail` package (for interactive UI mode): `apt-get install whiptail`

## Features

- **One-Liner Installation**: Install directly from GitHub with a single command
- **Proxmox Host Tools**: Automatically installs tmux, iftop, and htop on Proxmox host
- **Container Tools**: Pre-installs tmux, htop, and iftop inside containers
- **Multiple Configuration Modes**: 
  - **Quick Setup**: Fast deployment with sensible defaults
  - **Config File Mode**: Automated deployment using configuration file
  - **Advanced/Interactive Mode**: Step-by-step UI interface with full control
- **Service Selection**: Choose which services to install (NetBird, Cloudflare Tunnel, or both)
- **Template Management**: 
  - Automatic template detection
  - Automatic template download if not found
  - UI-based template selection
  - Separate template storage selection
- **Storage Management**: 
  - Separate storage pools for templates and container disks
  - Automatic detection or UI-based selection
- **Modular Design**: Each component is a separate script for easy maintenance
- **Reusable Functions**: Common functions library for shared utilities
- **Comprehensive Error Handling**: Robust error checking and logging
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

This project is licensed under the MIT License.

Copyright (c) 2024 ClawCMD

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Support

For issues or questions, please open an issue on the GitHub repository.

