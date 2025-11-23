#!/usr/bin/env bash

# ClawCMD - Cloudflare Tunnel Installation Script
# Installs and configures Cloudflared tunnel in an LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_cloudflared() {
    local ctid=$1
    
    log_info "Installing Cloudflared in container ${ctid}..."
    
    # Check if container is running
    if ! pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        log_info "Starting container ${ctid}..."
        pct start "$ctid"
        wait_for_container "$ctid"
        wait_for_network "$ctid"
    fi
    
    # Install Cloudflared
    log_info "Installing Cloudflared packages..."
    pct exec "$ctid" -- bash -c '
        set -e
        apt-get update -qq
        apt-get install -y ca-certificates curl
        
        # Add Cloudflare repository
        mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg > /usr/share/keyrings/cloudflare-main.gpg
        
        cat > /etc/apt/sources.list.d/cloudflared.sources <<EOF
Types: deb
URIs: https://pkg.cloudflare.com/cloudflared/
Suites: any
Components: main
Signed-By: /usr/share/keyrings/cloudflare-main.gpg
EOF
        
        # Update and install
        apt-get update -qq
        apt-get install -y cloudflared
    '
    
    log_success "Cloudflared installed successfully"
}

configure_cloudflared() {
    local ctid=$1
    local token="${CLOUDFLARED_TOKEN:-}"
    
    if [[ -z "$token" ]]; then
        log_warning "Cloudflare tunnel token not provided. Skipping configuration."
        log_info "To configure Cloudflared manually, run: pct exec ${ctid} -- cloudflared service install <TOKEN>"
        return
    fi
    
    log_info "Configuring Cloudflared tunnel with token..."
    
    # Install cloudflared as a service with the token
    pct exec "$ctid" -- bash -c "cloudflared service install ${token}" || {
        log_error "Failed to configure Cloudflared tunnel"
        exit 1
    }
    
    # Start and enable the service
    pct exec "$ctid" -- bash -c "
        systemctl enable cloudflared
        systemctl start cloudflared
    "
    
    log_success "Cloudflared tunnel configured and started"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    check_proxmox
    
    if [[ -z "${CT_ID:-}" ]]; then
        log_error "CT_ID not set. Please provide container ID."
        exit 1
    fi
    
    install_cloudflared "$CT_ID"
    
    # Configure if token is provided
    if [[ -n "${CLOUDFLARED_TOKEN:-}" ]]; then
        configure_cloudflared "$CT_ID"
    fi
fi

