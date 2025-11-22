#!/usr/bin/env bash

# ClawCMD Cyber Club - UI Selection Functions
# Provides whiptail-based UI for template and storage selection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Show mini header for UI mode
show_ui_header() {
    if [[ -t 1 ]]; then  # Only show if terminal
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}     ${GREEN}ClawCMD${NC} - ${BLUE}Initial Infrastructure Setup${NC}     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}          ${YELLOW}Interactive Configuration${NC}          ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Select template using whiptail
select_template() {
    local preferred_os="${CT_OS:-ubuntu}"
    local preferred_version="${CT_VERSION:-22}"
    
    log_info "Scanning available templates..."
    
    # Get all available templates
    local templates
    templates=$(pvesm list local 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' || echo "")
    
    if [[ -z "$templates" ]]; then
        log_warning "No templates found locally."
        # Try to download template
        local template_name="${preferred_os}-${preferred_version}-standard"
        if download_template "$template_name"; then
            # Try again after download
            templates=$(pvesm list local 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' || echo "")
        fi
        
        if [[ -z "$templates" ]]; then
            log_error "No templates found. Please download a template from Proxmox web interface."
            exit 1
        fi
    fi
    
    # Build whiptail menu options
    local menu_options=()
    local selected_template=""
    
    # Try to find preferred template first
    local preferred_template
    preferred_template=$(echo "$templates" | grep -i "${preferred_os}-${preferred_version}" | head -1 || echo "")
    
    # Build menu from templates
    while IFS= read -r template; do
        if [[ -n "$template" ]]; then
            local template_name
            template_name=$(basename "$template" | sed 's/\.tar\.zst$//' | sed 's/\.tar\.gz$//')
            menu_options+=("$template" "$template_name")
            
            # Set as default if it matches preferred
            if [[ -n "$preferred_template" && "$template" == "$preferred_template" ]]; then
                selected_template="$template"
            fi
        fi
    done <<< "$templates"
    
    # If we have a preferred template, use it
    if [[ -n "$selected_template" && "${USE_UI:-0}" == "0" ]]; then
        echo "$selected_template"
        return 0
    fi
    
    # Show UI selection if USE_UI is enabled or no preferred template found
    if [[ "${USE_UI:-0}" == "1" || -z "$selected_template" ]]; then
        if ! command -v whiptail &> /dev/null; then
            log_warning "whiptail not available, using first template: $(echo "$templates" | head -1)"
            echo "$(echo "$templates" | head -1)"
            return 0
        fi
        
        local choice
        choice=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Select Template" \
            --menu "Choose a container template:" \
            20 60 10 \
            "${menu_options[@]}" \
            3>&1 1>&2 2>&3) || {
            log_error "Template selection cancelled"
            exit 1
        }
        
        echo "$choice"
    else
        echo "$selected_template"
    fi
}

# Select storage pool using whiptail
select_storage_pool() {
    local preferred_pool="${STORAGE_POOL:-}"
    
    log_info "Scanning available storage pools..."
    
    # Get all available storage pools (excluding templates and ISOs)
    local storage_pools
    storage_pools=$(pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -vE "vztmpl|iso" || echo "")
    
    if [[ -z "$storage_pools" ]]; then
        log_warning "No storage pools found, using default: local-lvm"
        echo "local-lvm"
        return 0
    fi
    
    # If preferred pool is set and exists, use it (unless UI is forced)
    if [[ -n "$preferred_pool" ]]; then
        if echo "$storage_pools" | grep -q "^${preferred_pool}$"; then
            if [[ "${USE_UI:-0}" == "0" ]]; then
                echo "$preferred_pool"
                return 0
            fi
        else
            log_warning "Preferred storage pool '${preferred_pool}' not found, showing selection menu"
        fi
    fi
    
    # Show UI selection if USE_UI is enabled
    if [[ "${USE_UI:-0}" == "1" ]]; then
        if ! command -v whiptail &> /dev/null; then
            log_warning "whiptail not available, using first pool: $(echo "$storage_pools" | head -1)"
            echo "$(echo "$storage_pools" | head -1)"
            return 0
        fi
        
        # Build menu options
        local menu_options=()
        local default_item=""
        local item_num=0
        
        while IFS= read -r pool; do
            if [[ -n "$pool" ]]; then
                menu_options+=("$pool" "Storage Pool")
                if [[ "$pool" == "local-lvm" ]]; then
                    default_item="$item_num"
                fi
                ((item_num++))
            fi
        done <<< "$storage_pools"
        
        local choice
        choice=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Select Storage Pool" \
            --menu "Choose a storage pool for the container:" \
            15 50 8 \
            "${menu_options[@]}" \
            --default-item "${default_item:-0}" \
            3>&1 1>&2 2>&3) || {
            log_error "Storage pool selection cancelled"
            exit 1
        }
        
        echo "$choice"
    else
        # Use first available pool or preferred
        if [[ -n "$preferred_pool" && $(echo "$storage_pools" | grep -q "^${preferred_pool}$") ]]; then
            echo "$preferred_pool"
        else
            echo "$(echo "$storage_pools" | head -1)"
        fi
    fi
}

# Show mode selection menu
select_config_mode() {
    if ! command -v whiptail &> /dev/null; then
        log_error "whiptail is required for interactive mode. Please install it: apt-get install whiptail"
        exit 1
    fi
    
    show_ui_header
    
    local choice
    choice=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Configuration Mode" \
        --menu "Choose how you want to configure the deployment:" \
        15 70 4 \
        "default" "Quick setup (NetBird, Cloudflare, Template, Storage)" \
        "advanced" "Full step-by-step configuration (All options)" \
        "config" "Use existing configuration file" \
        "cancel" "Cancel and exit" \
        3>&1 1>&2 2>&3) || {
        log_info "Configuration cancelled"
        exit 0
    }
    
    case "$choice" in
        default)
            return 0  # Return 0 for default mode
            ;;
        advanced)
            return 2  # Return 2 for advanced mode
            ;;
        config)
            return 1  # Return 1 for config file mode
            ;;
        cancel)
            log_info "Deployment cancelled"
            exit 0
            ;;
        *)
            log_error "Invalid selection"
            exit 1
            ;;
    esac
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

# Download template if it doesn't exist
download_template() {
    local template_name="${1:-ubuntu-22-standard}"
    local os_type="${CT_OS:-ubuntu}"
    local os_version="${CT_VERSION:-22}"
    
    log_info "Checking for template: ${template_name}..."
    
    # Check if template already exists
    if pvesm list local 2>/dev/null | grep -qi "${template_name}"; then
        log_success "Template ${template_name} already exists"
        return 0
    fi
    
    log_info "Template not found. Attempting to download..."
    
    # Try to download using pveam
    if command -v pveam &> /dev/null; then
        # Update template list
        log_info "Updating template list..."
        pveam update || {
            log_warning "Failed to update template list, continuing..."
        }
        
        # Try to download the template
        local template_full_name="${os_type}-${os_version}-standard_amd64.tar.zst"
        log_info "Downloading template: ${template_full_name}..."
        
        if pveam download local "${template_full_name}" 2>/dev/null; then
            log_success "Template downloaded successfully"
            return 0
        else
            log_warning "Failed to download template automatically"
            log_info "Available templates:"
            pveam available --section system | grep -i "${os_type}" | head -5 || true
            echo ""
            log_info "Please download the template manually from Proxmox web interface"
            return 1
        fi
    else
        log_warning "pveam not available, cannot download template automatically"
        return 1
    fi
}

# Default configuration (quick setup)
default_config() {
    if ! command -v whiptail &> /dev/null; then
        log_error "whiptail is required for interactive mode. Please install it: apt-get install whiptail"
        exit 1
    fi
    
    show_ui_header
    log_info "Starting quick setup configuration..."
    
    # Set defaults
    CT_ID=$(get_next_available_ctid)
    CT_HOSTNAME="netbirdlxc"
    CT_CPU=2
    CT_RAM=1024
    CT_SWAP=1024
    CT_STORAGE=8
    CT_OS="ubuntu"
    CT_VERSION="22"
    CT_BRIDGE="vmbr0"
    CT_NETWORK="dhcp"
    CT_UNPRIVILEGED=1
    NETBIRD_ENABLED=1
    CLOUDFLARED_ENABLED=1
    INSTALL_PROXMOX_TOOLS=1
    
    # Display current settings
    whiptail --backtitle "ClawCMD Deployment" \
        --title "Quick Setup - Default Settings" \
        --msgbox "Using default settings:\n\nContainer ID: ${CT_ID}\nHostname: ${CT_HOSTNAME}\nCPU: ${CT_CPU} cores\nRAM: ${CT_RAM} MiB\nStorage: ${CT_STORAGE} GB\n\nYou will configure:\n- NetBird setup\n- Cloudflare Tunnel\n- Template location\n- Storage pool" \
        12 70
    
    # NetBird Management URL
    NETBIRD_MANAGEMENT_URL=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "NetBird Management URL" \
        --inputbox "Enter NetBird management URL (leave blank for default):" \
        8 60 "${NETBIRD_MANAGEMENT_URL:-}" \
        3>&1 1>&2 2>&3) || NETBIRD_MANAGEMENT_URL=""
    
    # NetBird Setup Key
    NETBIRD_SETUP_KEY=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "NetBird Setup Key" \
        --inputbox "Enter NetBird setup key (required):" \
        8 60 "${NETBIRD_SETUP_KEY:-}" \
        3>&1 1>&2 2>&3) || {
        log_error "NetBird setup key is required"
        exit 1
    }
    
    if [[ -z "$NETBIRD_SETUP_KEY" ]]; then
        log_error "NetBird setup key cannot be empty"
        exit 1
    fi
    
    # Cloudflare Tunnel Token
    CLOUDFLARED_TOKEN=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Cloudflare Tunnel Token" \
        --inputbox "Enter Cloudflare tunnel token (required):" \
        8 60 "${CLOUDFLARED_TOKEN:-}" \
        3>&1 1>&2 2>&3) || {
        log_error "Cloudflare tunnel token is required"
        exit 1
    }
    
    if [[ -z "$CLOUDFLARED_TOKEN" ]]; then
        log_error "Cloudflare tunnel token cannot be empty"
        exit 1
    fi
    
    # Template selection with download option
    export USE_UI=1
    local selected_template
    selected_template=$(select_template)
    
    if [[ -z "$selected_template" ]]; then
        log_error "Template selection failed. Please ensure a template is available."
        exit 1
    fi
    
    CT_TEMPLATE="$selected_template"
    
    # Storage pool selection
    local selected_pool
    selected_pool=$(select_storage_pool)
    STORAGE_POOL="$selected_pool"
    
    # Confirm settings
    local confirm_msg="Configuration Summary:\n\n"
    confirm_msg+="Container ID: ${CT_ID}\n"
    confirm_msg+="Hostname: ${CT_HOSTNAME}\n"
    confirm_msg+="Resources: ${CT_CPU} CPU, ${CT_RAM} MiB RAM, ${CT_STORAGE} GB Storage\n"
    confirm_msg+="Template: $(basename ${CT_TEMPLATE})\n"
    confirm_msg+="Storage Pool: ${STORAGE_POOL}\n"
    confirm_msg+="NetBird: Enabled\n"
    confirm_msg+="Cloudflare Tunnel: Enabled\n\n"
    confirm_msg+="Proceed with deployment?"
    
    if ! whiptail --backtitle "ClawCMD Deployment" \
        --title "Confirm Deployment" \
        --yesno "$confirm_msg" \
        15 70; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    log_success "Quick setup configuration completed"
}

# Interactive configuration wizard
interactive_config() {
    if ! command -v whiptail &> /dev/null; then
        log_error "whiptail is required for interactive mode. Please install it: apt-get install whiptail"
        exit 1
    fi
    
    show_ui_header
    log_info "Starting interactive configuration wizard..."
    
    # Container ID
    local next_id
    next_id=$(pvesh get /cluster/nextid 2>/dev/null || echo "1000")
    CT_ID=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Container ID" \
        --inputbox "Enter Container ID:" \
        8 60 "${CT_ID:-$next_id}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # Hostname
    CT_HOSTNAME=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Hostname" \
        --inputbox "Enter container hostname:" \
        8 60 "${CT_HOSTNAME:-netbirdlxc}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # CPU
    CT_CPU=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "CPU Cores" \
        --inputbox "Enter number of CPU cores:" \
        8 60 "${CT_CPU:-2}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # RAM
    CT_RAM=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "RAM (MiB)" \
        --inputbox "Enter RAM in MiB:" \
        8 60 "${CT_RAM:-1024}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # Storage
    CT_STORAGE=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Storage (GB)" \
        --inputbox "Enter storage size in GB:" \
        8 60 "${CT_STORAGE:-8}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # Swap
    CT_SWAP=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Swap (MiB)" \
        --inputbox "Enter swap size in MiB:" \
        8 60 "${CT_SWAP:-1024}" \
        3>&1 1>&2 2>&3) || exit 1
    
    # Template selection
    export USE_UI=1
    local selected_template
    selected_template=$(select_template)
    CT_TEMPLATE="$selected_template"
    
    # Storage pool selection
    local selected_pool
    selected_pool=$(select_storage_pool)
    STORAGE_POOL="$selected_pool"
    
    # NetBird
    NETBIRD_ENABLED=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "NetBird" \
        --yesno "Install NetBird?" \
        8 60) && NETBIRD_ENABLED=1 || NETBIRD_ENABLED=0
    
    if [[ "$NETBIRD_ENABLED" == "1" ]]; then
        NETBIRD_SETUP_KEY=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "NetBird Setup Key" \
            --inputbox "Enter NetBird setup key:" \
            8 60 "${NETBIRD_SETUP_KEY:-}" \
            3>&1 1>&2 2>&3) || NETBIRD_SETUP_KEY=""
        
        NETBIRD_MANAGEMENT_URL=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "NetBird Management URL (Optional)" \
            --inputbox "Enter NetBird management URL (leave blank for default):" \
            8 60 "${NETBIRD_MANAGEMENT_URL:-}" \
            3>&1 1>&2 2>&3) || NETBIRD_MANAGEMENT_URL=""
    fi
    
    # Cloudflared
    CLOUDFLARED_ENABLED=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Cloudflare Tunnel" \
        --yesno "Install Cloudflare Tunnel?" \
        8 60) && CLOUDFLARED_ENABLED=1 || CLOUDFLARED_ENABLED=0
    
    if [[ "$CLOUDFLARED_ENABLED" == "1" ]]; then
        CLOUDFLARED_TOKEN=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Cloudflare Tunnel Token" \
            --inputbox "Enter Cloudflare tunnel token:" \
            8 60 "${CLOUDFLARED_TOKEN:-}" \
            3>&1 1>&2 2>&3) || CLOUDFLARED_TOKEN=""
    fi
    
    log_success "Interactive configuration completed"
}

