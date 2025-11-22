#!/usr/bin/env bash

# ClawCMD Cyber Club - Container Tools Installation Script
# Installs essential tools (tmux, htop, iftop) inside an LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_container_tools() {
    local ctid=$1
    
    log_info "Installing essential tools in container ${ctid}..."
    
    # Check if container is running
    if ! pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        log_info "Starting container ${ctid}..."
        pct start "$ctid"
        wait_for_container "$ctid"
        wait_for_network "$ctid"
    fi
    
    # Detect OS type for package manager
    local os_type
    os_type=$(pct exec "$ctid" -- cat /etc/os-release 2>/dev/null | grep -i "^ID=" | cut -d'=' -f2 | tr -d '"' || echo "debian")
    
    log_info "Detected OS: ${os_type}"
    
    # Install tools based on OS type
    if [[ "$os_type" == "alpine" ]]; then
        log_info "Installing tools using apk (Alpine Linux)..."
        pct exec "$ctid" -- sh -c '
            set -e
            apk update -q
            apk add -q tmux htop iftop || {
                echo "Warning: Some tools may not be available in Alpine repositories"
                apk add -q tmux htop 2>/dev/null || true
            }
        '
    else
        # Debian/Ubuntu
        log_info "Installing tools using apt (Debian/Ubuntu)..."
        pct exec "$ctid" -- bash -c '
            set -e
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y tmux htop iftop
        '
    fi
    
    log_success "Essential tools installed successfully in container"
    echo ""
    log_info "Installed tools in container:"
    log_info "  - tmux: Terminal multiplexer"
    log_info "  - htop: Interactive process viewer"
    log_info "  - iftop: Network traffic monitor"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    check_proxmox
    
    if [[ -z "${CT_ID:-}" ]]; then
        log_error "CT_ID not set. Please provide container ID."
        exit 1
    fi
    
    install_container_tools "$CT_ID"
fi

