#!/usr/bin/env bash

# ClawCMD Cyber Club - Initial Infrastructure Setup Script
# Main deployment script for the club's main infrastructure
# 
# Purpose: First-time setup for new infrastructure or after Proxmox reset
# This script sets up basic remote access by deploying an Ubuntu LXC container
# with NetBird (VPN) and Cloudflare Tunnel for secure remote connectivity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Source common functions
source "${SCRIPTS_DIR}/common.sh"

# Default config file
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/env.conf}"

usage() {
    cat <<EOF
ClawCMD Cyber Club - Initial Infrastructure Setup Script
Main deployment script for the club's main infrastructure

Purpose: First-time setup for new infrastructure or after Proxmox reset
This script sets up basic remote access by deploying an Ubuntu LXC container
with NetBird (VPN) and Cloudflare Tunnel for secure remote connectivity.

Usage: $0 [OPTIONS]

Options:
    -c, --config FILE    Use configuration file mode (default: env.conf)
    -i, --interactive    Use interactive UI mode (default behavior)
    -h, --help           Show this help message

Examples:
    $0                    # Interactive UI mode (default)
    $0 -i                 # Interactive UI mode (explicit)
    $0 -c                 # Use config file mode
    $0 -c /path/to/custom.conf

Modes:
    Interactive Mode (Default): Step-by-step UI interface for configuration
    Config File Mode: Uses env.conf for all settings

Configuration File:
    Copy env.conf.example to env.conf and modify the values.

When to use this script:
    - Setting up new Proxmox infrastructure
    - After wiping/resetting Proxmox
    - Initial deployment of basic remote access services

EOF
}

main() {
    local interactive_mode=1  # Default to interactive mode
    local config_file_mode=0
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_file_mode=1
                interactive_mode=0
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -i|--interactive)
                interactive_mode=1
                config_file_mode=0
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_root
    check_proxmox
    
    # Show header (only in config mode, not interactive)
    if [[ $config_file_mode -eq 1 ]]; then
        show_header
    fi
    
    # Interactive mode (default)
    if [[ $interactive_mode -eq 1 ]]; then
        source "${SCRIPTS_DIR}/ui-selector.sh"
        
        # Show mode selection menu
        local mode_result
        mode_result=$(select_config_mode; echo $?)
        
        case "$mode_result" in
            0)
                # User chose default/quick setup mode
                # Load config file as defaults if it exists
                if [[ -f "$CONFIG_FILE" ]]; then
                    log_info "Loading defaults from: ${CONFIG_FILE}"
                    source "$CONFIG_FILE"
                fi
                default_config
                # Build tags after configuration
                CT_TAGS=$(build_tags)
                ;;
            1)
                # User chose config file mode
                config_file_mode=1
                interactive_mode=0
                ;;
            2)
                # User chose advanced/interactive mode
                # Load config file as defaults if it exists
                if [[ -f "$CONFIG_FILE" ]]; then
                    log_info "Loading defaults from: ${CONFIG_FILE}"
                    source "$CONFIG_FILE"
                fi
                interactive_config
                # Build tags after configuration
                CT_TAGS=$(build_tags)
                ;;
            *)
                log_error "Invalid mode selection"
                exit 1
                ;;
        esac
    fi
    
    # Config file mode
    if [[ $config_file_mode -eq 1 ]]; then
        # Config file mode
        log_info "Loading configuration from: ${CONFIG_FILE}"
        validate_config "$CONFIG_FILE"
        source "$CONFIG_FILE"
        
        # Build tags dynamically based on enabled services
        CT_TAGS=$(build_tags)
        
        # Export config variables for child scripts
        export CT_ID CT_HOSTNAME CT_CPU CT_RAM CT_STORAGE CT_SWAP
        export CT_BRIDGE CT_NETWORK CT_UNPRIVILEGED STORAGE_POOL CT_TAGS
        export CT_OS CT_VERSION CT_TEMPLATE
        export NETBIRD_ENABLED NETBIRD_MANAGEMENT_URL NETBIRD_SETUP_KEY
        export CLOUDFLARED_ENABLED CLOUDFLARED_TOKEN
        export INSTALL_PROXMOX_TOOLS="${INSTALL_PROXMOX_TOOLS:-1}"
        export USE_UI=0
        
        # Display deployment plan
        log_info "=== Deployment Plan ==="
        log_info "Container ID: ${CT_ID}"
        log_info "Hostname: ${CT_HOSTNAME}"
        log_info "Resources: ${CT_CPU} CPU, ${CT_RAM} MiB RAM, ${CT_SWAP} MiB SWAP, ${CT_STORAGE} GB Storage"
        log_info "NetBird: $([ "${NETBIRD_ENABLED:-0}" == "1" ] && echo "Enabled" || echo "Disabled")"
        log_info "Cloudflared: $([ "${CLOUDFLARED_ENABLED:-0}" == "1" ] && echo "Enabled" || echo "Disabled")"
        echo ""
        
        # Confirm deployment
        read -p "Proceed with deployment? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            exit 0
        fi
    fi
    
    # Export variables (common for both modes)
    if [[ $interactive_mode -eq 1 ]]; then
        export USE_UI=1
        # Skip confirmation in interactive mode (user already confirmed in UI)
        log_info "Configuration completed via UI, proceeding with deployment..."
        # Export CT_TAGS (already built in mode branches)
        export CT_TAGS
        # Export all configuration variables for child scripts
        export CT_ID CT_HOSTNAME CT_CPU CT_RAM CT_STORAGE CT_SWAP
        export CT_BRIDGE CT_NETWORK CT_UNPRIVILEGED STORAGE_POOL
        export CT_OS CT_VERSION CT_TEMPLATE
        export NETBIRD_ENABLED NETBIRD_MANAGEMENT_URL NETBIRD_SETUP_KEY
        export CLOUDFLARED_ENABLED CLOUDFLARED_TOKEN
        export INSTALL_PROXMOX_TOOLS="${INSTALL_PROXMOX_TOOLS:-1}"
    else
        export USE_UI=0
        # CT_TAGS already exported in config file mode branch
    fi
    
    # Step 0: Install Proxmox host tools (optional)
    if [[ "${INSTALL_PROXMOX_TOOLS:-1}" == "1" ]]; then
        log_info "=== Step 0: Installing Proxmox Host Tools ==="
        if bash "${SCRIPTS_DIR}/install-proxmox-tools.sh"; then
            log_success "Proxmox host tools installed"
        else
            log_warning "Failed to install Proxmox host tools, continuing..."
        fi
        echo ""
    fi
    
    # Step 1: Create container
    log_info "=== Step 1: Creating LXC Container ==="
    bash "${SCRIPTS_DIR}/create-container.sh"
    
    # Wait for container to be ready
    wait_for_container "$CT_ID"
    sleep 3
    wait_for_network "$CT_ID"
    
    # Step 2: Install NetBird (if enabled)
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        log_info "=== Step 2: Installing NetBird ==="
        bash "${SCRIPTS_DIR}/install-netbird.sh"
    else
        log_info "=== Step 2: NetBird installation skipped ==="
    fi
    
    # Step 3: Install Cloudflared (if enabled)
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        log_info "=== Step 3: Installing Cloudflared ==="
        bash "${SCRIPTS_DIR}/install-cloudflared.sh"
    else
        log_info "=== Step 3: Cloudflared installation skipped ==="
    fi
    
    # Update container notes with final service information
    log_info "=== Updating Container Notes ==="
    set_container_notes "$CT_ID" 1
    
    # Display completion information
    show_completion
    log_success "=== Deployment Complete ==="
    echo ""
    log_info "Container Information:"
    log_info "  ID: ${CT_ID}"
    log_info "  Hostname: ${CT_HOSTNAME}"
    
    # Get container IP
    local container_ip
    container_ip=$(pct exec "$CT_ID" -- ip -4 addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1 || echo "N/A")
    log_info "  IP Address: ${container_ip}"
    
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                              ${YELLOW}Next Steps:${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        if [[ -z "${NETBIRD_SETUP_KEY:-}" ]]; then
            echo -e "${CYAN}║${NC}  ${GREEN}•${NC} Configure NetBird: ${BLUE}pct exec ${CT_ID} -- netbird up --setup-key <KEY>${NC}     ${CYAN}║${NC}"
        else
            echo -e "${CYAN}║${NC}  ${GREEN}•${NC} Check NetBird status: ${BLUE}pct exec ${CT_ID} -- netbird status${NC}            ${CYAN}║${NC}"
        fi
    fi
    
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        if [[ -z "${CLOUDFLARED_TOKEN:-}" ]]; then
            echo -e "${CYAN}║${NC}  ${GREEN}•${NC} Configure Cloudflared: ${BLUE}pct exec ${CT_ID} -- cloudflared service install <TOKEN>${NC} ${CYAN}║${NC}"
        else
            echo -e "${CYAN}║${NC}  ${GREEN}•${NC} Check Cloudflared status: ${BLUE}pct exec ${CT_ID} -- systemctl status cloudflared${NC}  ${CYAN}║${NC}"
        fi
    fi
    
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Container is ready for use!${NC}"
    echo ""
}

# Run main function
main "$@"

