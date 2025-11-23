#!/usr/bin/env bash

# ClawCMD - LXC Container Creation Script
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
    
    # Select or use configured template
    local template
    if [[ -n "$CT_TEMPLATE" ]]; then
        template="$CT_TEMPLATE"
        log_info "Using configured template: ${template}"
    else
        # Use UI selector if available, otherwise auto-detect
        if command -v select_template &> /dev/null; then
            # Capture only stdout (template path), stderr goes to terminal
            template=$(select_template 2>/dev/null | head -1)
        else
            # Fallback to auto-detection
            local template_storage="${TEMPLATE_STORAGE:-local}"
            template=$(pvesm list "$template_storage" 2>/dev/null | grep -i "${CT_OS}-${CT_VERSION}" | grep -i "vztmpl" | head -1 | awk '{print $1}' || echo "")
            if [[ -z "$template" ]]; then
                template=$(pvesm list "$template_storage" 2>/dev/null | grep -i "${CT_OS}" | grep -i "${CT_VERSION}" | grep -i "vztmpl" | head -1 | awk '{print $1}' || echo "")
            fi
        fi
        
        if [[ -z "$template" ]]; then
            log_error "Template not found. Please download a template from Proxmox web interface."
            log_info "Available templates:"
            pvesm list "${TEMPLATE_STORAGE:-local}" 2>/dev/null | grep -i "vztmpl" || true
            exit 1
        fi
        log_info "Selected template: ${template}"
    fi
    
    # Clean template path - ensure it's in correct format (storage:vztmpl/template-name.tar.zst)
    # Remove any extra whitespace, newlines, and ensure proper format
    template=$(echo "$template" | \
        tr -d '\n\r\t' | \
        awk '{print $1}' | \
        sed 's/[[:space:]]*$//' | \
        sed 's/^[[:space:]]*//' | \
        head -1)
    
    # Validate template path is not empty
    if [[ -z "$template" ]]; then
        log_error "Template path is empty after cleaning"
        log_error "This may indicate that select_template output was invalid"
        exit 1
    fi
    
    # Validate template path doesn't contain log message patterns (safety check)
    if [[ "$template" =~ \[(INFO|WARNING|ERROR|SUCCESS)\] ]] || [[ "$template" =~ ^(ℹ️|📋|✅|❌|⚠️) ]]; then
        log_error "Template path appears to contain log messages: ${template}"
        log_error "This indicates a problem with template selection output"
        exit 1
    fi
    
    # Validate template path length (Proxmox limit is 255 characters)
    if [[ ${#template} -gt 255 ]]; then
        log_error "Template path is too long (${#template} characters, max 255): ${template}"
        log_error "Please use a shorter template path or specify CT_TEMPLATE directly"
        exit 1
    fi
    
    # Log the cleaned template path for debugging
    log_info "Using template: ${template} (length: ${#template} characters)"
    
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
    
    # Build pct create command (ProxmoxVE pattern - build array to avoid eval issues)
    local pct_args=(
        "create"
        "${CT_ID}"
        "${template}"
        "--hostname" "${CT_HOSTNAME}"
        "--cores" "${CT_CPU}"
        "--memory" "${CT_RAM}"
        "--swap" "${CT_SWAP}"
    )
    
    # Add rootfs with storage pool
    if [[ -n "$STORAGE_POOL" ]]; then
        pct_args+=("--rootfs" "${STORAGE_POOL}:${CT_STORAGE}")
    else
        pct_args+=("--rootfs" "local-lvm:${CT_STORAGE}")
    fi
    
    # Add network
    if [[ "$CT_NETWORK" == "dhcp" ]]; then
        pct_args+=("--net0" "name=eth0,bridge=${CT_BRIDGE},ip=dhcp")
    else
        pct_args+=("--net0" "name=eth0,bridge=${CT_BRIDGE},ip=${CT_NETWORK}")
    fi
    
    # Add unprivileged flag
    pct_args+=("--unprivileged" "${CT_UNPRIVILEGED}")
    
    # Add onboot
    pct_args+=("--onboot" "1")
    
    # Add tags if specified (properly quoted to handle semicolons)
    if [[ -n "${CT_TAGS:-}" ]]; then
        pct_args+=("--tags" "${CT_TAGS}")
    fi
    
    # Execute the command (ProxmoxVE pattern - direct execution without eval)
    log_info "Executing: pct ${pct_args[*]}"
    pct "${pct_args[@]}"
    
    # Configure TUN device for NetBird (if enabled) - must be done before starting
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        configure_tun_device
    fi
    
    # Start container and wait for it to be ready (ProxmoxVE pattern)
    log_info "Starting container ${CT_ID}..."
    pct start "$CT_ID" || {
        log_warning "Container may already be running or failed to start"
    }
    
    # Wait for container to be running (with timeout)
    local max_wait=30
    local waited=0
    while [[ $waited -lt $max_wait ]]; do
        if pct status "$CT_ID" 2>/dev/null | grep -q "status: running"; then
            log_success "Container ${CT_ID} is running"
            break
        fi
        sleep 1
        ((waited++))
    done
    
    if [[ $waited -ge $max_wait ]]; then
        log_warning "Container ${CT_ID} did not start within ${max_wait} seconds, but continuing..."
    fi
    
    # Set container notes (only if container is running)
    if pct status "$CT_ID" 2>/dev/null | grep -q "status: running"; then
        set_container_notes "$CT_ID"
    else
        log_warning "Skipping container notes - container is not running"
    fi
    
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

