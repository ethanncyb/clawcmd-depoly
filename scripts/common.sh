#!/usr/bin/env bash

# ClawCMD - Common Functions Library
# Reusable utilities for container deployment

set -euo pipefail

# Color codes for output (only define if not already set)
# Check if variables are already defined to avoid readonly conflicts
if [[ -z "${RED:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m' # No Color
    readonly RED GREEN YELLOW BLUE CYAN MAGENTA NC
fi

# Display ClawCMD ASCII art header
show_header() {
    local clear_screen="${1:-1}"
    if [[ "$clear_screen" == "1" ]]; then
        clear
    fi
    cat <<"EOF"
                                                                                                    
                                       @%%%%%%%@                                                    
                                   @%%%%%%%% %%@                                                    
                                @%%%%%@      %%@                                                    
                             @%%%%          %%%                                                     
                           @%%%            %%%@                                                     
                         @%%@             %%%%                                                      
                         %%              @%%@                                                       
                        %%               %%%@                                                       
                       %%%                %%%%%                                                     
                      %%%                     %%%        @%%%%%%%%%%%%%%%%%%%%%%@                   
                     %%%@                      %%@  %%%% @%%%@@                %                    
                   %%%%%%%%                   %%@ %%%%                       @%%@                   
               @%%%%%@   %%%%                %%@%%%@                       @%%%                     
             %%%%@         %%%             @%%%%%@                       %%%%                       
          %%%%@             %%%@           %%%%%                    %%%%%%@                         
         %%%%        @%@     %%%            %%%                   %%%%                              
         @%%      @%%%%%      %%%          %%                     @%%%%%                            
     @%%%%%%@    %%%%          @%%%%@@    %%%                         @%%                           
   %%%%%@         %%%            @%%%%%%@%%@                           %%%                          
 @%%%                                  %%%@                            %%%                          
 %%%%%%%%%%%%                          %%%                    %%%%%%%%%%%                           
         @%%%                        %%%@                     %%                                    
      %%%%%@                        @%%                       %%                                    
     %%%%%@%%%%%%                                             %%                                    
       @%%%@@%%%%@                                           @%%                                    
               @%%                                    @@%%%%%%%@                                    
                %%                                   %%%%@%@%%%%%                                   
               @%%                                              %%%%%                               
               %%%                                                 @%%%@                            
               @%%                                                    %%%%%                         
               %%%                                                       @%%%%%                     
               %%%                                                           %%%%                   
                %%%                                                             %%%%                
                @%%%                                                               %%%%@            
                  %%%                                                                @@%%%          
                   @%%%@@              %%%                                              @%%%%       
                     @%%%%%%@          %%%                                                 @%%%@    
                   %%%%%%%%%%%%%%%     %%              %%%%%%%%%%%%%%@                        %%%@  
     @%%%%%  %%%%%%%%%%%%     %@%%%%%%@%%     @%%%%%%%%%%%%@@@@@@%%%%%%       @@                @%  
        @%%%%%%%@                   %%%%%%%%%%%%%%@%                 %%%@    @%%@    @%%%@%@%@%%%%  
       %%%%%%%@                        %%                             @%%%  @%%%%%   %%@%%%%%%%%@   
    %%%%%%%%%                          %%                               %%%%%%%@%%%@ @%%            
          %%%                          %%%                                       @%%%%%@            
           %%                          %%%                                                          
                                      %%%%                                                          
                                    @%%%%%%                                                         
                                   %%%@  %%%@                                                       
                                  %%@      %%                                                       
                                                                                                    
EOF
    echo -e "${CYAN}_________ .__                _________                                           .___${NC}"
    echo -e "${CYAN}\_   ___ \|  | _____ __  _  _\_   ___ \  ____   _____   _____ _____    ____    __| _/${NC}"
    echo -e "${CYAN}/    \  \/|  | \__  \\ \/ \/ /    \  \/ /  _ \ /     \ /     \\__  \  /    \  / __ | ${NC}"
    echo -e "${CYAN}\     \___|  |__/ __ \\     /\     \___(  <_> )  Y Y  \  Y Y  \/ __ \|   |  \/ /_/ | ${NC}"
    echo -e "${CYAN} \______  /____(____  /\/\_/  \______  /\____/|__|_|  /__|_|  (____  /___|  /\____ | ${NC}"
    echo -e "${CYAN}        \/          \/               \/             \/      \/     \/     \/      \/ ${NC}"
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}                    ${GREEN}ClawCMD${NC} - ${BLUE}Initial Infrastructure Setup${NC}                     ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}                    ${YELLOW}Basic Remote Access Deployment${NC}                             ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Build Proxmox tags based on enabled services
build_tags() {
    local base_tag="${CT_TAGS:-core-services}"
    local tags="$base_tag"
    
    # Add netbird tag if enabled
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        tags="${tags};netbird"
    fi
    
    # Add cloudflared tag if enabled
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        tags="${tags};cloudflared"
    fi
    
    echo "$tags"
}

# Set container notes/description in Proxmox
set_container_notes() {
    local ctid=$1
    local hostname="${CT_HOSTNAME:-netbirdlxc}"
    local tags="${CT_TAGS:-core-services}"
    local update_after_services="${2:-0}"  # Set to 1 to update after services are installed
    
    # Get container IP if available
    local container_ip=""
    if pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        container_ip=$(pct exec "$ctid" -- ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "")
    fi
    
    # Build notes content
    local notes="<div align='center'>"
    notes+="<h2>ClawCMD - Infrastructure Container</h2>"
    notes+="<p><strong>Hostname:</strong> ${hostname}</p>"
    notes+="<p><strong>Container ID:</strong> ${ctid}</p>"
    if [[ -n "$container_ip" ]]; then
        notes+="<p><strong>IP Address:</strong> ${container_ip}</p>"
    fi
    notes+="<p><strong>Tags:</strong> ${tags}</p>"
    notes+="<hr>"
    notes+="<h3>Services</h3>"
    notes+="<ul style='text-align: left; display: inline-block;'>"
    
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        notes+="<li>✅ <strong>NetBird VPN</strong> - Enabled</li>"
        if [[ -n "${NETBIRD_MANAGEMENT_URL:-}" ]]; then
            notes+="<li>   Management URL: ${NETBIRD_MANAGEMENT_URL}</li>"
        fi
        if [[ "$update_after_services" == "1" ]]; then
            notes+="<li>   Status: Check with <code>pct exec ${ctid} -- netbird status</code></li>"
        fi
    else
        notes+="<li>❌ <strong>NetBird VPN</strong> - Disabled</li>"
    fi
    
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        notes+="<li>✅ <strong>Cloudflare Tunnel</strong> - Enabled</li>"
        if [[ "$update_after_services" == "1" ]]; then
            notes+="<li>   Status: Check with <code>pct exec ${ctid} -- systemctl status cloudflared</code></li>"
        fi
    else
        notes+="<li>❌ <strong>Cloudflare Tunnel</strong> - Disabled</li>"
    fi
    
    notes+="</ul>"
    notes+="<hr>"
    notes+="<h3>Resources</h3>"
    notes+="<ul style='text-align: left; display: inline-block;'>"
    notes+="<li><strong>CPU:</strong> ${CT_CPU:-2} cores</li>"
    notes+="<li><strong>RAM:</strong> ${CT_RAM:-1024} MiB</li>"
    notes+="<li><strong>Storage:</strong> ${CT_STORAGE:-8} GB</li>"
    notes+="<li><strong>Swap:</strong> ${CT_SWAP:-1024} MiB</li>"
    notes+="</ul>"
    notes+="<hr>"
    notes+="<p><strong>Deployed:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>"
    notes+="<p><strong>Purpose:</strong> Basic remote access infrastructure</p>"
    notes+="<p><em>Deployed by ClawCMD Infrastructure Management</em></p>"
    notes+="</div>"
    
    # Set the description
    pct set "$ctid" -description "$notes" 2>/dev/null || {
        log_warning "Failed to set container notes"
        return 1
    }
    
    if [[ "$update_after_services" == "1" ]]; then
        log_success "Container notes updated with service information"
    else
        log_success "Container notes set"
    fi
}

# Display completion message with ASCII art
show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                    ${CYAN}✓ Deployment Completed Successfully! ✓${NC}                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Message functions
# Icons for messages
CROSS="${CROSS:-❌}"
CHECKMARK="${CHECKMARK:-✅}"
INFO="${INFO:-ℹ️}"
WARN="${WARN:-⚠️}"

msg_info() {
    echo -e "${INFO}${BLUE} $1${NC}"
}

msg_ok() {
    echo -e "${CHECKMARK}${GREEN} $1${NC}"
}

msg_error() {
    echo -e "${CROSS}${RED} $1${NC}"
}

msg_warn() {
    echo -e "${WARN}${YELLOW} $1${NC}"
}

# Check if running as root
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check if Proxmox VE is installed
check_proxmox() {
    if ! command -v pveversion &> /dev/null; then
        log_error "Proxmox VE is not installed or not in PATH"
        exit 1
    fi
}

# Check if container ID is available
check_ctid_available() {
    local ctid=$1
    if pct list | grep -q "^[[:space:]]*${ctid}[[:space:]]"; then
        log_error "Container ID ${ctid} is already in use"
        exit 1
    fi
}

# Wait for container to be running
wait_for_container() {
    local ctid=$1
    local max_attempts=30
    local attempt=0
    
    log_info "Waiting for container ${ctid} to start..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
            log_success "Container ${ctid} is running"
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    log_error "Container ${ctid} failed to start within ${max_attempts} seconds"
    return 1
}

# Wait for network connectivity in container
wait_for_network() {
    local ctid=$1
    local max_attempts=20
    local attempt=0
    
    log_info "Waiting for network connectivity in container ${ctid}..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if pct exec "$ctid" -- ping -c1 -W1 8.8.8.8 &>/dev/null; then
            log_success "Network connectivity established"
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    log_warning "Network connectivity check failed, but continuing..."
    return 1
}

# Get next available container ID
get_next_ctid() {
    pvesh get /cluster/nextid 2>/dev/null || echo "100"
}

# Get next available container ID starting from 1000
get_next_available_ctid() {
    local start_id=1000
    local current_id=$start_id
    
    while pct list 2>/dev/null | grep -q "^[[:space:]]*${current_id}[[:space:]]"; do
        ((current_id++))
    done
    
    echo "$current_id"
}

# Validate configuration file
validate_config() {
    local config_file=$1
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: ${config_file}"
        exit 1
    fi
    
    # Source the config file
    source "$config_file"
    
    # Validate required variables
    local required_vars=("CT_ID" "CT_HOSTNAME" "CT_CPU" "CT_RAM" "CT_STORAGE")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required configuration variable ${var} is not set"
            exit 1
        fi
    done
    
    # Validate numeric values
    if ! [[ "$CT_CPU" =~ ^[0-9]+$ ]] || [[ "$CT_CPU" -lt 1 ]]; then
        log_error "CT_CPU must be a positive integer"
        exit 1
    fi
    
    if ! [[ "$CT_RAM" =~ ^[0-9]+$ ]] || [[ "$CT_RAM" -lt 128 ]]; then
        log_error "CT_RAM must be at least 128 MiB"
        exit 1
    fi
    
    if ! [[ "$CT_STORAGE" =~ ^[0-9]+$ ]] || [[ "$CT_STORAGE" -lt 2 ]]; then
        log_error "CT_STORAGE must be at least 2 GB"
        exit 1
    fi
    
    # Validate template and storage pool configuration BEFORE applying defaults
    # If both CT_TEMPLATE and STORAGE_POOL are empty in config, show error
    local template_empty=0
    local storage_empty=0
    
    if [[ -z "${CT_TEMPLATE:-}" ]]; then
        template_empty=1
    fi
    
    if [[ -z "${STORAGE_POOL:-}" ]]; then
        storage_empty=1
    fi
    
    if [[ $template_empty -eq 1 ]] && [[ $storage_empty -eq 1 ]]; then
        log_error "Configuration error: Both CT_TEMPLATE and STORAGE_POOL cannot be empty"
        log_error ""
        log_error "Please set at least one of the following in your config file:"
        log_error "  - CT_TEMPLATE: Full template path (e.g., local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst)"
        log_error "  - STORAGE_POOL: Container storage pool (e.g., local-lvm) - where container disk will be saved"
        log_error ""
        log_error "Note: There are TWO different storage settings:"
        log_error "  - TEMPLATE_STORAGE: Where templates are stored (default: local)"
        log_error "  - STORAGE_POOL: Where container disk will be saved (default: local-lvm)"
        log_error ""
        log_error "Recommended: Set STORAGE_POOL=local-lvm and TEMPLATE_STORAGE=local"
        log_error "The script will then auto-detect the latest template based on CT_OS and CT_VERSION"
        exit 1
    fi
    
    # Set defaults for optional values (after validation)
    CT_OS="${CT_OS:-debian}"
    CT_VERSION="${CT_VERSION:-13}"
    CT_SWAP="${CT_SWAP:-1024}"
    CT_BRIDGE="${CT_BRIDGE:-vmbr0}"
    CT_NETWORK="${CT_NETWORK:-dhcp}"
    CT_UNPRIVILEGED="${CT_UNPRIVILEGED:-1}"
    STORAGE_POOL="${STORAGE_POOL:-local-lvm}"
    TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
    NETBIRD_ENABLED="${NETBIRD_ENABLED:-0}"
    CLOUDFLARED_ENABLED="${CLOUDFLARED_ENABLED:-0}"
    INSTALL_PROXMOX_TOOLS="${INSTALL_PROXMOX_TOOLS:-1}"
    
    log_success "Configuration file validated"
}

