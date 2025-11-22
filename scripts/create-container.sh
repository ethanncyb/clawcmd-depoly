#!/usr/bin/env bash

# ClawCMD Cyber Club - LXC Container Creation Script
# Creates an Ubuntu LXC container with specified resources

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default values
CT_ID="${CT_ID:-}"
CT_HOSTNAME="${CT_HOSTNAME:-netbirdlxc}"
CT_CPU="${CT_CPU:-2}"
CT_RAM="${CT_RAM:-1024}"
CT_STORAGE="${CT_STORAGE:-8}"
CT_OS="${CT_OS:-debian}"
CT_VERSION="${CT_VERSION:-13}"
CT_UNPRIVILEGED="${CT_UNPRIVILEGED:-1}"
CT_BRIDGE="${CT_BRIDGE:-vmbr0}"
CT_NETWORK="${CT_NETWORK:-dhcp}"
CT_SWAP="${CT_SWAP:-1024}"
STORAGE_POOL="${STORAGE_POOL:-}"
CT_TEMPLATE="${CT_TEMPLATE:-}"

# Source UI selector functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui-selector.sh" 2>/dev/null || true

create_container() {
    # Validate required variables
    if [[ -z "${CT_ID:-}" ]]; then
        log_error "CT_ID is not set. Please set CT_ID before creating container."
        exit 1
    fi
    
    if [[ -z "${CT_HOSTNAME:-}" ]]; then
        log_error "CT_HOSTNAME is not set. Please set CT_HOSTNAME before creating container."
        exit 1
    fi
    
    log_info "Creating LXC container ${CT_ID} (${CT_HOSTNAME})..."
    
    # Check if CTID is available
    check_ctid_available "$CT_ID"
    
    # Build pct create command
    local pct_cmd="pct create ${CT_ID}"
    
    # Select or use configured template
    local template
    if [[ -n "$CT_TEMPLATE" ]]; then
        template="$CT_TEMPLATE"
        log_info "Using configured template: ${template}"
    else
        # Use UI selector if available, otherwise auto-detect
        if command -v select_template &> /dev/null; then
            template=$(select_template)
        else
            # Fallback to auto-detection
            template=$(pvesm list local | grep -i "${CT_OS}-${CT_VERSION}" | grep -i "vztmpl" | head -1 | awk '{print $1}' || echo "")
            if [[ -z "$template" ]]; then
                template=$(pvesm list local | grep -i "${CT_OS}" | grep -i "${CT_VERSION}" | grep -i "vztmpl" | head -1 | awk '{print $1}' || echo "")
            fi
        fi
        
        if [[ -z "$template" ]]; then
            log_error "Template not found. Please download a template from Proxmox web interface."
            log_info "Available templates:"
            pvesm list local | grep -i "vztmpl" || true
            exit 1
        fi
        log_info "Selected template: ${template}"
    fi
    
    pct_cmd="${pct_cmd} ${template}"
    
    # Select or use configured storage pool
    if [[ -z "$STORAGE_POOL" ]]; then
        # Use UI selector if available
        if command -v select_storage_pool &> /dev/null; then
            STORAGE_POOL=$(select_storage_pool)
        else
            # Fallback to default
            STORAGE_POOL="local-lvm"
        fi
    fi
    
    log_info "Using storage pool: ${STORAGE_POOL}"
    
    # Add hostname
    pct_cmd="${pct_cmd} --hostname ${CT_HOSTNAME}"
    
    # Add resources
    pct_cmd="${pct_cmd} --cores ${CT_CPU}"
    pct_cmd="${pct_cmd} --memory ${CT_RAM}"
    pct_cmd="${pct_cmd} --swap ${CT_SWAP}"
    
    # Add rootfs with storage pool
    if [[ -n "$STORAGE_POOL" ]]; then
        pct_cmd="${pct_cmd} --rootfs ${STORAGE_POOL}:${CT_STORAGE}"
    else
        pct_cmd="${pct_cmd} --rootfs local-lvm:${CT_STORAGE}"
    fi
    
    # Add network
    if [[ "$CT_NETWORK" == "dhcp" ]]; then
        pct_cmd="${pct_cmd} --net0 name=eth0,bridge=${CT_BRIDGE},ip=dhcp"
    else
        pct_cmd="${pct_cmd} --net0 name=eth0,bridge=${CT_BRIDGE},ip=${CT_NETWORK}"
    fi
    
    # Add unprivileged flag
    pct_cmd="${pct_cmd} --unprivileged ${CT_UNPRIVILEGED}"
    
    # Add onboot
    pct_cmd="${pct_cmd} --onboot 1"
    
    # Add tags if specified
    if [[ -n "${CT_TAGS:-}" ]]; then
        pct_cmd="${pct_cmd} --tags ${CT_TAGS}"
    fi
    
    # Execute the command
    log_info "Executing: ${pct_cmd}"
    eval "$pct_cmd"
    
    # Configure TUN device for NetBird (if enabled)
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        configure_tun_device
    fi
    
    # Set container notes
    set_container_notes "$CT_ID"
    
    log_success "Container ${CT_ID} created successfully"
}

configure_tun_device() {
    log_info "Configuring TUN device for NetBird..."
    
    local lxc_config="/etc/pve/lxc/${CT_ID}.conf"
    
    # Check if TUN configuration already exists
    if grep -q "lxc.cgroup2.devices.allow: c 10:200 rwm" "$lxc_config" 2>/dev/null; then
        log_warning "TUN device already configured"
        return
    fi
    
    # Add TUN device configuration
    cat >> "$lxc_config" <<EOF

# NetBird TUN device configuration
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
    
    log_success "TUN device configured"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    check_proxmox
    
    # Source config if provided
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        source "$CONFIG_FILE"
    fi
    
    create_container
fi

