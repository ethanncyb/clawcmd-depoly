#!/usr/bin/env bash

# ClawCMD - UI Selection Functions
# Provides whiptail-based UI for template and storage selection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Icons for UI display
CONTAINERID="${CONTAINERID:-📦}"
OS="${OS:-🐧}"
DISKSIZE="${DISKSIZE:-💾}"
CPUCORE="${CPUCORE:-⚙️}"
RAMSIZE="${RAMSIZE:-🧠}"
NETWORK="${NETWORK:-🌐}"
HOSTNAME="${HOSTNAME:-🏷️}"
TEMPLATE="${TEMPLATE:-📋}"
STORAGE="${STORAGE:-💿}"
CREATING="${CREATING:-🔨}"
DEFAULT="${DEFAULT:-⚙️}"
ADVANCED="${ADVANCED:-🔧}"
DGN="${DGN:-${CYAN}}"
BGN="${BGN:-${GREEN}}"
BOLD="${BOLD:-\033[1m}"
CL="${CL:-${NC}}"
BL="${BL:-${BLUE}}"
RD="${RD:-${RED}}"
YW="${YW:-${YELLOW}}"

# Show mini header for UI mode
# Note: This is a simpler header used during interactive configuration
# The full ASCII art header is shown at script start
show_ui_header() {
    if [[ -t 1 ]]; then  # Only show if terminal
        # Don't clear screen here - main header already cleared it
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}            ${GREEN}ClawCMD${NC} - ${BLUE}Initial Infrastructure Setup${NC}            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                  ${YELLOW}Interactive Configuration${NC}                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Display default settings summary
echo_default_settings() {
    local container_type_desc="Unprivileged"
    if [[ "${CT_UNPRIVILEGED:-1}" == "0" ]]; then
        container_type_desc="Privileged"
    fi
    
    echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}${CT_ID}${CL}"
    echo -e "${OS}${BOLD}${DGN}Operating System: ${BGN}${CT_OS} (${CT_VERSION})${CL}"
    echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${CT_HOSTNAME}${CL}"
    echo -e "${CONTAINERID}${BOLD}${DGN}Container Type: ${BGN}${container_type_desc}${CL}"
    echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${CT_STORAGE} GB${CL}"
    echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CT_CPU}${CL}"
    echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${CT_RAM} MiB${CL}"
    if [[ -n "${CT_SWAP:-}" && "${CT_SWAP:-0}" != "0" ]]; then
        echo -e "${RAMSIZE}${BOLD}${DGN}Swap Size: ${BGN}${CT_SWAP} MiB${CL}"
    fi
    if [[ -n "${TEMPLATE_STORAGE:-}" ]]; then
        echo -e "${STORAGE}${BOLD}${DGN}Template Storage: ${BGN}${TEMPLATE_STORAGE}${CL} (where templates are stored)"
    fi
    if [[ -n "${CT_TEMPLATE:-}" ]]; then
        local template_display
        template_display=$(basename "${CT_TEMPLATE}" 2>/dev/null || echo "${CT_TEMPLATE}")
        echo -e "${TEMPLATE}${BOLD}${DGN}Template: ${BGN}${template_display}${CL}"
    fi
    if [[ -n "${STORAGE_POOL:-}" ]]; then
        echo -e "${STORAGE}${BOLD}${DGN}Container Storage Pool: ${BGN}${STORAGE_POOL}${CL} (where container disk will be saved)"
    fi
    echo -e "${NETWORK}${BOLD}${DGN}Network: ${BGN}${CT_NETWORK}${CL}"
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        echo -e "${NETWORK}${BOLD}${DGN}NetBird: ${BGN}Enabled${CL}"
    fi
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        echo -e "${NETWORK}${BOLD}${DGN}Cloudflare Tunnel: ${BGN}Enabled${CL}"
    fi
    echo ""
    echo -e "${CREATING}${BOLD}${BLUE}Creating container with the above settings${CL}"
    echo ""
}

# Select template using whiptail
select_template() {
    local preferred_os="${CT_OS:-debian}"
    local preferred_version="${CT_VERSION:-13}"
    local template_storage="${TEMPLATE_STORAGE:-local}"
    
    log_info "Scanning available templates in ${template_storage}..." >&2
    
    # Get all available templates from the selected storage - ensure we only get the first column (template path)
    # Use timeout to prevent hanging (ProxmoxVE pattern)
    local templates=""
    if command -v timeout &> /dev/null; then
        templates=$(timeout 5 pvesm list "$template_storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
    else
        templates=$(pvesm list "$template_storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
    fi
    
    # If no templates in selected storage, try all storages
    if [[ -z "$templates" ]]; then
        log_warning "No templates found in ${template_storage}, checking all storages..." >&2
        local all_storages
        if command -v timeout &> /dev/null; then
            all_storages=$(timeout 5 pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -v '^$' || echo "")
        else
            all_storages=$(pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -v '^$' || echo "")
        fi
        
        while IFS= read -r storage; do
            if [[ -n "$storage" ]]; then
                local storage_templates
                if command -v timeout &> /dev/null; then
                    storage_templates=$(timeout 3 pvesm list "$storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
                else
                    storage_templates=$(pvesm list "$storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
                fi
                if [[ -n "$storage_templates" ]]; then
                    templates="${templates}${storage_templates}"$'\n'
                fi
            fi
        done <<< "$all_storages"
        templates=$(echo "$templates" | grep -v '^$' || echo "")
    fi
    
    if [[ -z "$templates" ]]; then
        log_warning "No templates found locally." >&2
        msg_info "No template found. Downloading template first..." >&2
        
        # Select template storage location first
        if [[ "${USE_UI:-0}" == "1" ]]; then
            msg_info "Selecting template storage location..." >&2
            template_storage=$(select_template_storage)
            TEMPLATE_STORAGE="$template_storage"
        fi
        
        # Try to download template to selected storage
        local template_name="${preferred_os}-${preferred_version}-standard"
        msg_info "Downloading template: ${template_name}..." >&2
        if download_template "$template_name" >&2; then
            msg_info "Template download completed. Scanning for downloaded template..." >&2
            # Try again after download (with timeout)
            if command -v timeout &> /dev/null; then
                templates=$(timeout 5 pvesm list "$template_storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
            else
                templates=$(pvesm list "$template_storage" 2>/dev/null | grep -i "vztmpl" | awk '{print $1}' | grep -v '^$' || echo "")
            fi
        fi
        
        if [[ -z "$templates" ]]; then
            log_error "No templates found. Please download a template from Proxmox web interface." >&2
            exit 1
        fi
    fi
    
    # Build whiptail menu options
    local menu_options=()
    local selected_template=""
    
    # Try to find preferred template - get the LATEST version (ProxmoxVE pattern)
    # Sort templates by version number to get the most recent
    local preferred_template=""
    local matching_templates
    
    # Find all matching templates and sort by version (latest first)
    matching_templates=$(echo "$templates" | grep -i "debian-13-standard" | sort -V -r || echo "")
    
    # If not found, try any debian-13 template
    if [[ -z "$matching_templates" ]]; then
        matching_templates=$(echo "$templates" | grep -i "${preferred_os}-${preferred_version}" | sort -V -r || echo "")
    fi
    
    # Get the latest (first after reverse sort)
    if [[ -n "$matching_templates" ]]; then
        preferred_template=$(echo "$matching_templates" | head -1)
    fi
    
    # Build menu from templates - sort by version (latest first) for better UX
    local sorted_templates
    sorted_templates=$(echo "$templates" | sort -V -r)
    
    while IFS= read -r template; do
        if [[ -n "$template" ]]; then
            local template_name
            template_name=$(basename "$template" | sed 's/\.tar\.zst$//' | sed 's/\.tar\.gz$//')
            
            # Mark latest version
            local display_name="$template_name"
            if [[ "$template" == "$preferred_template" ]]; then
                display_name="${template_name} (Latest)"
                selected_template="$template"
            fi
            
            menu_options+=("$template" "$display_name")
        fi
    done <<< "$sorted_templates"
    
    # If we have a preferred template, use it
    if [[ -n "$selected_template" && "${USE_UI:-0}" == "0" ]]; then
        # Clean template path - ensure it's a valid template path
        selected_template=$(echo "$selected_template" | awk '{print $1}' | grep -E '^[^[]+$' | head -1)
        if [[ -z "$selected_template" ]]; then
            log_error "Invalid template path after cleaning" >&2
            exit 1
        fi
        local template_display_name
        template_display_name=$(basename "$selected_template" 2>/dev/null || echo "$selected_template")
        echo -e "${TEMPLATE}${BOLD}${DGN}Template: ${BGN}${template_display_name}${CL}" >&2
        # Output ONLY the template path to stdout
        echo "$selected_template" | head -1
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
        
        # Clean choice - remove any extra whitespace and ensure proper format
        choice=$(echo "$choice" | tr -d '\n\r\t' | awk '{print $1}' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')
        
        if [[ -n "$choice" ]]; then
            # Validate template path length
            if [[ ${#choice} -gt 255 ]]; then
                log_error "Template path is too long (${#choice} characters, max 255): ${choice}" >&2
                exit 1
            fi
            
            local template_display_name
            template_display_name=$(basename "$choice" 2>/dev/null || echo "$choice")
            echo -e "${TEMPLATE}${BOLD}${DGN}Template: ${BGN}${template_display_name}${CL}" >&2
            # Output ONLY the template path to stdout
            echo "$choice" | head -1
        else
            log_error "Invalid template selection" >&2
            exit 1
        fi
    else
        # Clean template path - ensure it's a valid template path
        selected_template=$(echo "$selected_template" | awk '{print $1}' | grep -E '^[^[]+$' | head -1)
        if [[ -z "$selected_template" ]]; then
            log_error "Invalid template path after cleaning" >&2
            exit 1
        fi
        local template_display_name
        template_display_name=$(basename "$selected_template" 2>/dev/null || echo "$selected_template")
        echo -e "${TEMPLATE}${BOLD}${DGN}Template: ${BGN}${template_display_name}${CL}" >&2
        # Output ONLY the template path to stdout
        echo "$selected_template" | head -1
    fi
}

# Select storage pool using whiptail
select_storage_pool() {
    local preferred_pool="${STORAGE_POOL:-}"
    
    log_info "Scanning available storage pools..." >&2
    
    # Get all available storage pools (excluding templates and ISOs)
    # Use timeout to prevent hanging, and try multiple methods
    local storage_pools=""
    
    # Method 1: Try pvesm status with timeout (most reliable)
    if command -v timeout &> /dev/null; then
        storage_pools=$(timeout 5 pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -vE "^(vztmpl|iso)$" | grep -v '^$' || echo "")
    else
        storage_pools=$(pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -vE "^(vztmpl|iso)$" | grep -v '^$' || echo "")
    fi
    
    # Method 2: If pvesm fails, try pvesh API (ProxmoxVE pattern)
    if [[ -z "$storage_pools" ]] && command -v pvesh &> /dev/null; then
        if command -v timeout &> /dev/null; then
            storage_pools=$(timeout 5 pvesh get /storage 2>/dev/null | grep -oP '"storage":\s*"\K[^"]+' | grep -vE "^(vztmpl|iso)$" || echo "")
        else
            storage_pools=$(pvesh get /storage 2>/dev/null | grep -oP '"storage":\s*"\K[^"]+' | grep -vE "^(vztmpl|iso)$" || echo "")
        fi
    fi
    
    # Method 3: Try pvesm list as fallback
    if [[ -z "$storage_pools" ]] && command -v pvesm &> /dev/null; then
        if command -v timeout &> /dev/null; then
            storage_pools=$(timeout 5 pvesm list 2>/dev/null | awk 'NR>1 {print $1}' | grep -vE "^(vztmpl|iso)$" | grep -v '^$' || echo "")
        else
            storage_pools=$(pvesm list 2>/dev/null | awk 'NR>1 {print $1}' | grep -vE "^(vztmpl|iso)$" | grep -v '^$' || echo "")
        fi
    fi
    
    # Method 4: Try common storage pool names as last resort
    if [[ -z "$storage_pools" ]]; then
        log_warning "Could not detect storage pools automatically, trying common defaults..." >&2
        for pool in local-lvm local; do
            if pvesm status "$pool" &>/dev/null 2>&1; then
                if [[ -z "$storage_pools" ]]; then
                    storage_pools="$pool"
                else
                    storage_pools="${storage_pools}"$'\n'"$pool"
                fi
            fi
        done
    fi
    
    if [[ -z "$storage_pools" ]]; then
        log_warning "No storage pools found, using default: local-lvm" >&2
        echo "local-lvm"
        return 0
    fi
    
    # If preferred pool is set and exists, use it (unless UI is forced)
    if [[ -n "$preferred_pool" ]]; then
        if echo "$storage_pools" | grep -q "^${preferred_pool}$"; then
            if [[ "${USE_UI:-0}" == "0" ]]; then
                echo -e "${STORAGE}${BOLD}${DGN}Container Storage Pool: ${BGN}${preferred_pool}${CL}" >&2
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
        
        # Build menu options with better descriptions (ProxmoxVE pattern)
        local menu_options=()
        local default_item=""
        local item_num=0
        
        while IFS= read -r pool; do
            if [[ -n "$pool" ]]; then
                # Get storage type for better description
                local storage_type=""
                local storage_info=""
                if command -v pvesm &> /dev/null; then
                    if command -v timeout &> /dev/null; then
                        storage_info=$(timeout 2 pvesm status "$pool" 2>/dev/null | awk 'NR==2 {print $2, $3}' || echo "")
                    else
                        storage_info=$(pvesm status "$pool" 2>/dev/null | awk 'NR==2 {print $2, $3}' || echo "")
                    fi
                    if [[ -n "$storage_info" ]]; then
                        storage_type=" ($storage_info)"
                    fi
                fi
                
                menu_options+=("$pool" "Storage${storage_type}")
                if [[ "$pool" == "local-lvm" ]] || [[ "$item_num" -eq 0 ]]; then
                    default_item="$item_num"
                fi
                ((item_num++))
            fi
        done <<< "$storage_pools"
        
        # Check if we have any options
        if [[ ${#menu_options[@]} -eq 0 ]]; then
            log_warning "No storage pools available for selection, using default: local-lvm" >&2
            echo "local-lvm"
            return 0
        fi
        
        local choice
        choice=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Select Container Storage Pool" \
            --menu "Choose storage pool where the container disk will be saved:\n\nThis is different from template storage.\nThis is where the container's root filesystem will be stored." \
            18 75 $(( ${#menu_options[@]} / 2 + 1 )) \
            "${menu_options[@]}" \
            --default-item "${default_item:-0}" \
            3>&1 1>&2 2>&3) || {
            log_error "Container storage pool selection cancelled"
            exit 1
        }
        
        # Clean choice - remove any extra whitespace
        choice=$(echo "$choice" | awk '{print $1}')
        
        if [[ -n "$choice" ]]; then
            echo -e "${STORAGE}${BOLD}${DGN}Container Storage Pool: ${BGN}${choice}${CL}" >&2
            echo "$choice"
        else
            log_error "Invalid storage pool selection"
            exit 1
        fi
    else
        # Use first available pool or preferred
        if [[ -n "$preferred_pool" && $(echo "$storage_pools" | grep -q "^${preferred_pool}$") ]]; then
            echo -e "${STORAGE}${BOLD}${DGN}Container Storage Pool: ${BGN}${preferred_pool}${CL}" >&2
            echo "$preferred_pool"
        else
            local first_pool=$(echo "$storage_pools" | head -1)
            echo -e "${STORAGE}${BOLD}${DGN}Container Storage Pool: ${BGN}${first_pool}${CL}" >&2
            echo "$first_pool"
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

# Select services to install (NetBird, Cloudflare Tunnel, or both)
select_services() {
    local netbird_selected="${NETBIRD_ENABLED:-0}"
    local cloudflared_selected="${CLOUDFLARED_ENABLED:-0}"
    
    # Build checklist options
    local checklist_options=()
    
    # NetBird option
    if [[ "$netbird_selected" == "1" ]]; then
        checklist_options+=("netbird" "NetBird VPN - Secure mesh VPN for remote access" "ON")
    else
        checklist_options+=("netbird" "NetBird VPN - Secure mesh VPN for remote access" "OFF")
    fi
    
    # Cloudflare Tunnel option
    if [[ "$cloudflared_selected" == "1" ]]; then
        checklist_options+=("cloudflared" "Cloudflare Tunnel - Secure tunnel to Cloudflare network" "ON")
    else
        checklist_options+=("cloudflared" "Cloudflare Tunnel - Secure tunnel to Cloudflare network" "OFF")
    fi
    
    if ! command -v whiptail &> /dev/null; then
        log_warning "whiptail not available, using defaults: NetBird=ON, Cloudflare=ON" >&2
        NETBIRD_ENABLED=1
        CLOUDFLARED_ENABLED=1
        return 0
    fi
    
    local selected_services
    selected_services=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Select Services" \
        --checklist "Choose which services to install in the container:\n\nUse SPACE to select/deselect, TAB to navigate, ENTER to confirm." \
        15 70 2 \
        "${checklist_options[@]}" \
        3>&1 1>&2 2>&3) || {
        log_error "Service selection cancelled" >&2
        exit 1
    }
    
    # Reset service flags
    NETBIRD_ENABLED=0
    CLOUDFLARED_ENABLED=0
    
    # Parse selected services
    if echo "$selected_services" | grep -q "netbird"; then
        NETBIRD_ENABLED=1
        echo -e "${NETWORK}${BOLD}${DGN}NetBird: ${BGN}Selected${CL}" >&2
    else
        echo -e "${NETWORK}${BOLD}${DGN}NetBird: ${BGN}Not Selected${CL}" >&2
    fi
    
    if echo "$selected_services" | grep -q "cloudflared"; then
        CLOUDFLARED_ENABLED=1
        echo -e "${NETWORK}${BOLD}${DGN}Cloudflare Tunnel: ${BGN}Selected${CL}" >&2
    else
        echo -e "${NETWORK}${BOLD}${DGN}Cloudflare Tunnel: ${BGN}Not Selected${CL}" >&2
    fi
    
    # Warn if no services selected
    if [[ "${NETBIRD_ENABLED:-0}" == "0" && "${CLOUDFLARED_ENABLED:-0}" == "0" ]]; then
        log_warning "No services selected. Container will be created without NetBird or Cloudflare Tunnel." >&2
    fi
    
    echo "" >&2
}

# Select template storage location (where templates are stored)
select_template_storage() {
    local preferred_storage="${TEMPLATE_STORAGE:-local}"
    
    log_info "Scanning available storage for templates..." >&2
    
    # Get all available storage pools that can store templates
    local storage_pools=""
    
    # Method 1: Try pvesm status with timeout
    if command -v timeout &> /dev/null; then
        storage_pools=$(timeout 5 pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -v '^$' || echo "")
    else
        storage_pools=$(pvesm status 2>/dev/null | awk 'NR>1 && $2=="active" {print $1}' | grep -v '^$' || echo "")
    fi
    
    # Method 2: If pvesm fails, try pvesh API
    if [[ -z "$storage_pools" ]] && command -v pvesh &> /dev/null; then
        if command -v timeout &> /dev/null; then
            storage_pools=$(timeout 5 pvesh get /storage 2>/dev/null | grep -oP '"storage":\s*"\K[^"]+' | grep -v '^$' || echo "")
        else
            storage_pools=$(pvesh get /storage 2>/dev/null | grep -oP '"storage":\s*"\K[^"]+' | grep -v '^$' || echo "")
        fi
    fi
    
    # Method 3: Try common storage names
    if [[ -z "$storage_pools" ]]; then
        log_warning "Could not detect storage pools automatically, trying common defaults..." >&2
        for pool in local local-lvm; do
            if pvesm status "$pool" &>/dev/null 2>&1; then
                if [[ -z "$storage_pools" ]]; then
                    storage_pools="$pool"
                else
                    storage_pools="${storage_pools}"$'\n'"$pool"
                fi
            fi
        done
        storage_pools=$(echo "$storage_pools" | grep -v '^$' || echo "")
    fi
    
    # If no storage found, use default
    if [[ -z "$storage_pools" ]]; then
        log_warning "No storage pools found, using default: local" >&2
        echo "local"
        return 0
    fi
    
    # If preferred storage is set and exists, use it (unless UI is forced)
    if [[ -n "$preferred_storage" ]]; then
        if echo "$storage_pools" | grep -q "^${preferred_storage}$"; then
            if [[ "${USE_UI:-0}" == "0" ]]; then
                echo -e "${STORAGE}${BOLD}${DGN}Template Storage: ${BGN}${preferred_storage}${CL}" >&2
                echo "$preferred_storage"
                return 0
            fi
        fi
    fi
    
    # Show UI selection if USE_UI is enabled
    if [[ "${USE_UI:-0}" == "1" ]]; then
        if ! command -v whiptail &> /dev/null; then
            log_warning "whiptail not available, using first storage: $(echo "$storage_pools" | head -1)" >&2
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
                if [[ "$pool" == "local" ]] || [[ "$item_num" -eq 0 ]]; then
                    default_item="$item_num"
                fi
                ((item_num++))
            fi
        done <<< "$storage_pools"
        
        if [[ ${#menu_options[@]} -eq 0 ]]; then
            log_warning "No storage pools available, using default: local" >&2
            echo "local"
            return 0
        fi
        
        local choice
        choice=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Select Template Storage" \
            --menu "Choose storage location for templates:\n\nThis is where container templates will be downloaded and stored." \
            17 70 $(( ${#menu_options[@]} / 2 + 1 )) \
            "${menu_options[@]}" \
            --default-item "${default_item:-0}" \
            3>&1 1>&2 2>&3) || {
            log_error "Template storage selection cancelled"
            exit 1
        }
        
        choice=$(echo "$choice" | awk '{print $1}')
        if [[ -n "$choice" ]]; then
            echo -e "${STORAGE}${BOLD}${DGN}Template Storage: ${BGN}${choice}${CL}" >&2
            echo "$choice"
        else
            log_error "Invalid template storage selection"
            exit 1
        fi
    else
        # Use first available pool or preferred
        if [[ -n "$preferred_storage" && $(echo "$storage_pools" | grep -q "^${preferred_storage}$") ]]; then
            echo -e "${STORAGE}${BOLD}${DGN}Template Storage: ${BGN}${preferred_storage}${CL}" >&2
            echo "$preferred_storage"
        else
            local first_pool=$(echo "$storage_pools" | head -1)
            echo -e "${STORAGE}${BOLD}${DGN}Template Storage: ${BGN}${first_pool}${CL}" >&2
            echo "$first_pool"
        fi
    fi
}

# Download template if it doesn't exist (with storage selection)
download_template() {
    local template_name="${1:-debian-13-standard}"
    local os_type="${CT_OS:-debian}"
    local os_version="${CT_VERSION:-13}"
    local template_storage="${TEMPLATE_STORAGE:-local}"
    
    log_info "Checking for template: ${template_name}..." >&2
    
    # Check if template already exists in any storage
    local template_exists=0
    if command -v timeout &> /dev/null; then
        if timeout 5 pvesm list "$template_storage" 2>/dev/null | grep -qi "${template_name}"; then
            template_exists=1
        fi
    else
        if pvesm list "$template_storage" 2>/dev/null | grep -qi "${template_name}"; then
            template_exists=1
        fi
    fi
    
    if [[ $template_exists -eq 1 ]]; then
        log_success "Template ${template_name} already exists in ${template_storage}" >&2
        return 0
    fi
    
    log_info "Template not found. Attempting to download..." >&2
    
    # Try to download using pveam
    if command -v pveam &> /dev/null; then
        # Update template list
        log_info "Updating template list..." >&2
        pveam update >&2 || {
            log_warning "Failed to update template list, continuing..." >&2
        }
        
        # Get the latest available template version (ProxmoxVE pattern)
        log_info "Finding latest template version..." >&2
        local available_templates
        if command -v timeout &> /dev/null; then
            # pveam available --section system outputs format:
            # system
            #   debian-13-standard_13.1-2_amd64.tar.zst  Debian 13 standard
            # We need to filter out the "system" header and get actual template names
            available_templates=$(timeout 10 pveam available --section system 2>/dev/null | \
                grep -iE "\.tar\.(zst|gz)" | \
                grep -iE "${os_type}-${os_version}-standard" | \
                awk '{print $1}' | \
                grep -v "^system$" | \
                sort -V -r || echo "")
        else
            available_templates=$(pveam available --section system 2>/dev/null | \
                grep -iE "\.tar\.(zst|gz)" | \
                grep -iE "${os_type}-${os_version}-standard" | \
                awk '{print $1}' | \
                grep -v "^system$" | \
                sort -V -r || echo "")
        fi
        
        # Get the latest template name (first line after sorting)
        local latest_template=""
        if [[ -n "$available_templates" ]]; then
            latest_template=$(echo "$available_templates" | head -1 | tr -d '\n\r\t' | awk '{print $1}')
            # Ensure it's a valid template filename (contains .tar.zst or .tar.gz)
            if [[ ! "$latest_template" =~ \.tar\.(zst|gz)$ ]]; then
                log_warning "Invalid template name format: ${latest_template}, trying fallback..." >&2
                latest_template=""
            fi
        fi
        
        # Try to download the latest template
        if [[ -n "${latest_template:-}" ]]; then
            log_info "Downloading latest template: ${latest_template} to ${template_storage}..." >&2
            if pveam download "$template_storage" "${latest_template}" >&2; then
                log_success "Template downloaded successfully to ${template_storage}" >&2
                return 0
            fi
        fi
        
        # Fallback: Try specific template name
        local template_full_name="debian-13-standard_13.1-2_amd64.tar.zst"
        log_info "Trying specific template: ${template_full_name}..." >&2
        if pveam download "$template_storage" "${template_full_name}" >&2; then
            log_success "Template downloaded successfully to ${template_storage}" >&2
            return 0
        fi
        
        # Last fallback: Try generic template name
        log_warning "Latest template not found, trying generic template name..." >&2
        template_full_name="${os_type}-${os_version}-standard_amd64.tar.zst"
        if pveam download "$template_storage" "${template_full_name}" >&2; then
            log_success "Template downloaded successfully to ${template_storage}" >&2
            return 0
        else
            log_warning "Failed to download template automatically" >&2
            log_info "Available templates:" >&2
            pveam available --section system 2>&1 | grep -i "${os_type}" | head -5 >&2 || true
            echo "" >&2
            log_info "Please download the template manually from Proxmox web interface" >&2
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
    
    # Set defaults
    CT_ID=$(get_next_available_ctid)
    CT_HOSTNAME="netbirdlxc"
    CT_CPU=2
    CT_RAM=1024
    CT_SWAP=1024
    CT_STORAGE=8
    CT_OS="debian"
    CT_VERSION="13"
    CT_BRIDGE="vmbr0"
    CT_NETWORK="dhcp"
    CT_UNPRIVILEGED=1
    NETBIRD_ENABLED=1
    CLOUDFLARED_ENABLED=1
    INSTALL_PROXMOX_TOOLS=1
    
    # Display default settings
    echo -e "${DEFAULT}${BOLD}${BLUE}Using Default Settings${CL}"
    echo_default_settings
    
    whiptail --backtitle "ClawCMD Deployment" \
        --title "Quick Setup - Default Settings" \
        --msgbox "Using default settings:\n\nContainer ID: ${CT_ID}\nHostname: ${CT_HOSTNAME}\nCPU: ${CT_CPU} cores\nRAM: ${CT_RAM} MiB\nDisk Size: ${CT_STORAGE} GB\n\nYou will configure:\n- Services to install (NetBird, Cloudflare Tunnel)\n- Template storage (where templates are stored)\n- Container template\n- Container storage pool (where container disk will be saved)" \
        15 75
    
    # Service Selection
    echo ""
    msg_info "Selecting services to install..."
    select_services
    
    # NetBird Configuration (only if selected)
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
        msg_info "Configuring NetBird VPN..."
        NETBIRD_MANAGEMENT_URL=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "NetBird Management URL" \
            --inputbox "Enter NetBird management URL:\n\nLeave blank to use default (https://api.netbird.io)" \
            10 70 "${NETBIRD_MANAGEMENT_URL:-}" \
            3>&1 1>&2 2>&3) || NETBIRD_MANAGEMENT_URL=""
        
        # NetBird Setup Key
        NETBIRD_SETUP_KEY=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "NetBird Setup Key" \
            --inputbox "Enter NetBird setup key (required):\n\nGet this from your NetBird management console." \
            10 70 "${NETBIRD_SETUP_KEY:-}" \
            3>&1 1>&2 2>&3) || {
            msg_error "NetBird setup key is required"
            exit 1
        }
        
        if [[ -z "$NETBIRD_SETUP_KEY" ]]; then
            msg_error "NetBird setup key cannot be empty"
            exit 1
        fi
        
        echo -e "${NETWORK}${BOLD}${DGN}NetBird Setup Key: ${BGN}********${CL}"
        if [[ -n "$NETBIRD_MANAGEMENT_URL" ]]; then
            echo -e "${NETWORK}${BOLD}${DGN}NetBird Management URL: ${BGN}${NETBIRD_MANAGEMENT_URL}${CL}"
        fi
        echo ""
    fi
    
    # Cloudflare Tunnel Configuration (only if selected)
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        msg_info "Configuring Cloudflare Tunnel..."
        CLOUDFLARED_TOKEN=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Cloudflare Tunnel Token" \
            --inputbox "Enter Cloudflare tunnel token (required):\n\nGet this from Cloudflare Zero Trust dashboard > Networks > Tunnels." \
            10 70 "${CLOUDFLARED_TOKEN:-}" \
            3>&1 1>&2 2>&3) || {
            msg_error "Cloudflare tunnel token is required"
            exit 1
        }
        
        if [[ -z "$CLOUDFLARED_TOKEN" ]]; then
            msg_error "Cloudflare tunnel token cannot be empty"
            exit 1
        fi
        
        echo -e "${NETWORK}${BOLD}${DGN}Cloudflare Token: ${BGN}********${CL}"
        echo ""
    fi
    
    # Template storage selection (where templates are stored/downloaded)
    export USE_UI=1
    msg_info "Selecting template storage location (where templates are stored)..."
    local template_storage
    template_storage=$(select_template_storage)
    TEMPLATE_STORAGE="$template_storage"
    echo ""
    
    # Template selection with download option
    msg_info "Selecting container template..."
    local selected_template
    selected_template=$(select_template)
    
    if [[ -z "$selected_template" ]]; then
        msg_error "Template selection failed. Please ensure a template is available."
        exit 1
    fi
    
    CT_TEMPLATE="$selected_template"
    echo ""
    
    # Container storage pool selection (where container disk will be saved)
    msg_info "Selecting container storage pool (where container disk will be saved)..."
    local selected_pool
    selected_pool=$(select_storage_pool)
    STORAGE_POOL="$selected_pool"
    echo ""
    
    # Display final configuration summary
    echo ""
    echo -e "${CREATING}${BOLD}${BLUE}Configuration Summary${CL}"
    echo_default_settings
    
    # Confirm settings
    local confirm_msg="Configuration Summary:\n\n"
    confirm_msg+="Container ID: ${CT_ID}\n"
    confirm_msg+="Hostname: ${CT_HOSTNAME}\n"
    confirm_msg+="Resources: ${CT_CPU} CPU, ${CT_RAM} MiB RAM, ${CT_STORAGE} GB Disk\n"
    local template_display
    template_display=$(basename "${CT_TEMPLATE}" 2>/dev/null || echo "${CT_TEMPLATE}")
    confirm_msg+="Template: ${template_display}\n"
    confirm_msg+="Template Storage: ${TEMPLATE_STORAGE} (where templates are stored)\n"
    confirm_msg+="Container Storage Pool: ${STORAGE_POOL} (where container disk will be saved)\n"
    confirm_msg+="NetBird: Enabled\n"
    confirm_msg+="Cloudflare Tunnel: Enabled\n\n"
    confirm_msg+="Proceed with deployment?"
    
    if ! whiptail --backtitle "ClawCMD Deployment" \
        --title "Confirm Deployment" \
        --yesno "$confirm_msg" \
        16 70; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    msg_ok "Quick setup configuration completed"
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
    echo -e "${CONTAINERID}${BOLD}${DGN}Container ID: ${BGN}${CT_ID}${CL}"
    
    # Hostname
    CT_HOSTNAME=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Hostname" \
        --inputbox "Enter container hostname:" \
        8 60 "${CT_HOSTNAME:-netbirdlxc}" \
        3>&1 1>&2 2>&3) || exit 1
    echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${CT_HOSTNAME}${CL}"
    
    # CPU
    CT_CPU=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "CPU Cores" \
        --inputbox "Enter number of CPU cores:" \
        8 60 "${CT_CPU:-2}" \
        3>&1 1>&2 2>&3) || exit 1
    echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CT_CPU}${CL}"
    
    # RAM
    CT_RAM=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "RAM (MiB)" \
        --inputbox "Enter RAM in MiB:" \
        8 60 "${CT_RAM:-1024}" \
        3>&1 1>&2 2>&3) || exit 1
    echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${CT_RAM} MiB${CL}"
    
    # Storage
    CT_STORAGE=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Storage (GB)" \
        --inputbox "Enter storage size in GB:" \
        8 60 "${CT_STORAGE:-8}" \
        3>&1 1>&2 2>&3) || exit 1
    echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${CT_STORAGE} GB${CL}"
    
    # Swap
    CT_SWAP=$(whiptail --backtitle "ClawCMD Deployment" \
        --title "Swap (MiB)" \
        --inputbox "Enter swap size in MiB:" \
        8 60 "${CT_SWAP:-1024}" \
        3>&1 1>&2 2>&3) || exit 1
    echo -e "${RAMSIZE}${BOLD}${DGN}Swap Size: ${BGN}${CT_SWAP} MiB${CL}"
    
    # Template storage selection (where templates are stored/downloaded)
    export USE_UI=1
    echo ""
    msg_info "Selecting template storage location (where templates are stored)..."
    local template_storage
    template_storage=$(select_template_storage)
    TEMPLATE_STORAGE="$template_storage"
    echo ""
    
    # Template selection
    msg_info "Selecting container template..."
    local selected_template
    selected_template=$(select_template)
    CT_TEMPLATE="$selected_template"
    echo ""
    
    # Container storage pool selection (where container disk will be saved)
    msg_info "Selecting container storage pool (where container disk will be saved)..."
    local selected_pool
    selected_pool=$(select_storage_pool)
    STORAGE_POOL="$selected_pool"
    echo ""
    
    # Service Selection
    msg_info "Selecting services to install..."
    select_services
    
    # NetBird Configuration (only if selected)
    if [[ "${NETBIRD_ENABLED:-0}" == "1" ]]; then
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
    
    # Cloudflare Tunnel Configuration (only if selected)
    if [[ "${CLOUDFLARED_ENABLED:-0}" == "1" ]]; then
        CLOUDFLARED_TOKEN=$(whiptail --backtitle "ClawCMD Deployment" \
            --title "Cloudflare Tunnel Token" \
            --inputbox "Enter Cloudflare tunnel token:" \
            8 60 "${CLOUDFLARED_TOKEN:-}" \
            3>&1 1>&2 2>&3) || CLOUDFLARED_TOKEN=""
    fi
    
    # Display final configuration summary
    echo ""
    echo -e "${CREATING}${BOLD}${BLUE}Configuration Summary${CL}"
    echo_default_settings
    
    msg_ok "Interactive configuration completed"
}

