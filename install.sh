#!/usr/bin/env bash

# ClawCMD Cyber Club - One-Liner Installation Script
# This script can be run directly from GitHub to clone and deploy the infrastructure
#
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/clawcmd-deploy/install.sh)"
#
# This script will:
# 1. Install essential tools (tmux, iftop, htop) on Proxmox host
# 2. Clone the repository
# 3. Run the initial infrastructure setup

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# GitHub repository URL (update this with your actual repo)
# You can override this by setting GITHUB_REPO environment variable
GITHUB_REPO="${GITHUB_REPO:-https://github.com/USERNAME/clawcmd-infra.git}"
REPO_DIR="${REPO_DIR:-/opt/clawcmd-deploy}"

# Repository subdirectory (if the clawcmd-deploy folder is in a subdirectory)
REPO_SUBDIR="${REPO_SUBDIR:-clawcmd-deploy}"

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

# Install essential tools on Proxmox host
install_proxmox_tools() {
    log_info "Installing essential tools on Proxmox host (tmux, iftop, htop)..."
    
    # Update package list
    apt-get update -qq
    
    # Install tools
    apt-get install -y tmux iftop htop || {
        log_error "Failed to install tools"
        exit 1
    }
    
    log_success "Essential tools installed successfully"
}

# Clone or update repository
setup_repository() {
    if [[ -d "$REPO_DIR" ]]; then
        log_warning "Repository directory already exists: $REPO_DIR"
        read -p "Update existing repository? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Updating repository..."
            cd "$REPO_DIR"
            git pull || {
                log_error "Failed to update repository"
                exit 1
            }
        else
            log_info "Using existing repository"
        fi
    else
        log_info "Cloning repository to $REPO_DIR..."
        
        # Check if git is installed
        if ! command -v git &> /dev/null; then
            log_info "Installing git..."
            apt-get update -qq
            apt-get install -y git
        fi
        
        # Clone repository
        git clone "$GITHUB_REPO" "$REPO_DIR" || {
            log_error "Failed to clone repository"
            exit 1
        }
        
        log_success "Repository cloned successfully"
    fi
}

# Main installation function
main() {
    clear
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
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${GREEN}ClawCMD Cyber Club${NC} - ${BLUE}One-Liner Installation${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "Starting ClawCMD infrastructure installation..."
    echo ""
    
    # Check prerequisites
    check_root
    check_proxmox
    
    # Step 1: Install Proxmox tools
    log_info "=== Step 1: Installing Proxmox Host Tools ==="
    install_proxmox_tools
    echo ""
    
    # Step 2: Setup repository
    log_info "=== Step 2: Setting up Repository ==="
    setup_repository
    echo ""
    
    # Step 3: Run initial setup
    log_info "=== Step 3: Running Initial Infrastructure Setup ==="
    
    # Navigate to repository directory (handle subdirectory if needed)
    if [[ -d "$REPO_DIR/$REPO_SUBDIR" ]]; then
        cd "$REPO_DIR/$REPO_SUBDIR"
    else
        cd "$REPO_DIR"
    fi
    
    if [[ ! -f "initial-setup.sh" ]]; then
        log_error "initial-setup.sh not found in repository"
        log_info "Current directory: $(pwd)"
        log_info "Repository directory: $REPO_DIR"
        exit 1
    fi
    
    chmod +x initial-setup.sh
    chmod +x scripts/*.sh 2>/dev/null || true
    
    log_success "Installation complete! Starting deployment..."
    echo ""
    
    # Run the initial setup script (defaults to interactive mode)
    # Pass through any arguments (user can use -c for config mode if desired)
    exec ./initial-setup.sh "$@"
}

# Run main function
main "$@"

