#!/usr/bin/env bash

# ClawCMD - NetBird Installation Script
# Installs and configures NetBird in an LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_netbird() {
    local ctid=$1
    
    log_info "Installing NetBird in container ${ctid}..."
    
    # Check if container is running
    if ! pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        log_info "Starting container ${ctid}..."
        pct start "$ctid"
        wait_for_container "$ctid"
        wait_for_network "$ctid"
    fi
    
    # Install NetBird
    log_info "Installing NetBird packages..."
    pct exec "$ctid" -- bash -c '
        set -e
        apt-get update -qq
        apt-get install -y ca-certificates gpg curl
        
        # Add NetBird repository
        curl -fsSL "https://pkgs.netbird.io/debian/public.key" | gpg --dearmor > /usr/share/keyrings/netbird-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main" > /etc/apt/sources.list.d/netbird.list
        
        # Update and install
        apt-get update -qq
        apt-get install -y netbird
        
        # Enable and start NetBird service
        systemctl enable netbird
    '
    
    log_success "NetBird installed successfully"
}

configure_netbird() {
    local ctid=$1
    local setup_key="${NETBIRD_SETUP_KEY:-}"
    local management_url="${NETBIRD_MANAGEMENT_URL:-}"
    
    if [[ -z "$setup_key" ]]; then
        log_warning "NetBird setup key not provided. Skipping configuration."
        log_info "To configure NetBird manually, run: pct exec ${ctid} -- netbird up --setup-key <KEY>"
        return
    fi
    
    log_info "Configuring NetBird with setup key..."
    
    # Build netbird up command
    local netbird_cmd="netbird up --setup-key ${setup_key}"
    
    if [[ -n "$management_url" ]]; then
        netbird_cmd="${netbird_cmd} --management-url ${management_url}"
    fi
    
    # Configure NetBird
    pct exec "$ctid" -- bash -c "$netbird_cmd" || {
        log_warning "NetBird configuration may have failed. Check container logs."
    }
    
    log_success "NetBird configured"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    check_proxmox
    
    if [[ -z "${CT_ID:-}" ]]; then
        log_error "CT_ID not set. Please provide container ID."
        exit 1
    fi
    
    install_netbird "$CT_ID"
    
    # Configure if setup key is provided
    if [[ -n "${NETBIRD_SETUP_KEY:-}" ]]; then
        configure_netbird "$CT_ID"
    fi
fi

