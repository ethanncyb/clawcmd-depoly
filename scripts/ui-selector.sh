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
        log_error "No templates found. Please download a template from Proxmox web interface."
        exit 1
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

