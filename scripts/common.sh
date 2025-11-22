#!/usr/bin/env bash

# ClawCMD Cyber Club - Common Functions Library
# Reusable utilities for container deployment

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

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
    echo -e "${MAGENTA}║${NC}              ${GREEN}ClawCMD Cyber Club${NC} - ${BLUE}Initial Infrastructure Setup${NC}              ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}                    ${YELLOW}Basic Remote Access Deployment${NC}                      ${MAGENTA}║${NC}"
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

# Display completion message with ASCII art
show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                    ${CYAN}✓ Deployment Completed Successfully! ✓${NC}                    ${GREEN}║${NC}"
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
    
    log_success "Configuration file validated"
}

