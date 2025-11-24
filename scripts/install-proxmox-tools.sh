#!/usr/bin/env bash

# ClawCMD - Proxmox Host Tools Installation
# Installs essential tools on the Proxmox host: tmux, iftop, htop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_tools() {
    log_info "Installing essential tools on Proxmox host..."
    
    # Check if running on Proxmox host (not in container)
    if [[ -f /etc/pve/version ]]; then
        log_info "Detected Proxmox VE host"
    else
        log_warning "This script is designed to run on Proxmox VE host"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
    
    # Update package list
    log_info "Updating package list..."
    apt-get update -qq
    
    # Install tools
    log_info "Installing tmux, iftop, htop..."
    apt-get install -y tmux iftop htop vim || {
        log_error "Failed to install tools"
        exit 1
    }
    
    log_success "Essential tools installed successfully"
    echo ""
    log_info "Installed tools:"
    log_info "  - tmux: Terminal multiplexer"
    log_info "  - iftop: Network traffic monitor"
    log_info "  - htop: Interactive process viewer"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    
    install_tools
fi

