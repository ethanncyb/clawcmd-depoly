#!/usr/bin/env bash

# ClawCMD - Nginx Proxy Manager Installation Script
# Installs and configures Nginx Proxy Manager in an LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

install_nginxproxymanager() {
    local ctid=$1
    
    log_info "Installing Nginx Proxy Manager in container ${ctid}..."
    
    # Check if container is running
    if ! pct status "$ctid" 2>/dev/null | grep -q "status: running"; then
        log_info "Starting container ${ctid}..."
        pct start "$ctid"
        wait_for_container "$ctid"
        wait_for_network "$ctid"
    fi
    
    # Check Debian version (must be 13+)
    local debian_version
    debian_version=$(pct exec "$ctid" -- grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d'"' -f2 | cut -d'.' -f1 || echo "")
    if [[ "$debian_version" == "12" ]]; then
        log_error "Debian 12 detected. Nginx Proxy Manager requires Debian 13+"
        log_info "Please use a Debian 13+ template"
        exit 1
    fi
    
    log_info "Installing Nginx Proxy Manager..."
    pct exec "$ctid" -- bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        
        # Update system
        apt-get update -qq
        apt-get install -y ca-certificates curl gpg git build-essential python3 python3-pip sqlite3
        
        # Install Node.js 22
        if ! command -v node &>/dev/null || [[ $(node --version | cut -d"v" -f2 | cut -d"." -f1) != "22" ]]; then
            # Remove old Node.js if exists
            if command -v node &>/dev/null; then
                systemctl stop openresty 2>/dev/null || true
                systemctl stop npm 2>/dev/null || true
                apt-get purge -y nodejs npm 2>/dev/null || true
                apt-get autoremove -y
                rm -rf /usr/local/bin/node /usr/local/bin/npm
                rm -rf /usr/local/lib/node_modules
                rm -rf ~/.npm /root/.npm
            fi
            
            # Install Node.js 22
            curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
            apt-get install -y nodejs
        fi
        
        # Install Yarn
        if ! command -v yarn &>/dev/null; then
            npm install -g yarn
        fi
        
        # Set NODE_OPTIONS for build
        export NODE_OPTIONS="--max_old_space_size=2048 --openssl-legacy-provider"
        
        # Download and setup Nginx Proxy Manager
        RELEASE="2.13.4"
        INSTALL_DIR="/opt/nginxproxymanager"
        
        # Clean old installation if exists
        if [[ -d "$INSTALL_DIR" ]]; then
            rm -rf "$INSTALL_DIR"
        fi
        
        # Download release
        mkdir -p "$INSTALL_DIR"
        cd /tmp
        curl -fsSL "https://github.com/NginxProxyManager/nginx-proxy-manager/archive/refs/tags/v${RELEASE}.tar.gz" -o nginx-proxy-manager.tar.gz
        tar -xzf nginx-proxy-manager.tar.gz
        mv nginx-proxy-manager-${RELEASE}/* "$INSTALL_DIR/"
        rm -rf nginx-proxy-manager-${RELEASE} nginx-proxy-manager.tar.gz
        
        # Setup environment
        ln -sf /usr/bin/python3 /usr/bin/python
        
        # Clean old files
        rm -rf /app /var/www/html /etc/nginx /var/log/nginx /var/lib/nginx /var/cache/nginx
        
        # Setup directories
        mkdir -p /var/www/html /etc/nginx/logs /app/frontend/images
        mkdir -p /tmp/nginx/body /run/nginx
        mkdir -p /data/nginx /data/custom_ssl /data/logs /data/access
        mkdir -p /data/nginx/default_host /data/nginx/default_www
        mkdir -p /data/nginx/proxy_host /data/nginx/redirection_host
        mkdir -p /data/nginx/stream /data/nginx/dead_host /data/nginx/temp
        mkdir -p /var/lib/nginx/cache/public /var/lib/nginx/cache/private
        mkdir -p /var/cache/nginx/proxy_temp
        
        chmod -R 777 /var/cache/nginx
        chown root /tmp/nginx
        
        # Install OpenResty (Nginx)
        if [[ ! -f /etc/apt/trusted.gpg.d/openresty.gpg ]]; then
            curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/openresty.gpg
        fi
        
        if [[ ! -f /etc/apt/sources.list.d/openresty.sources ]]; then
            cat > /etc/apt/sources.list.d/openresty.sources <<EOF
Types: deb
URIs: http://openresty.org/package/debian/
Suites: bookworm
Components: openresty
Signed-By: /etc/apt/trusted.gpg.d/openresty.gpg
EOF
        fi
        
        apt-get update -qq
        apt-get install -y openresty
        
        # Link OpenResty Nginx
        ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx
        ln -sf /usr/local/openresty/nginx/ /etc/nginx
        
        # Copy Nginx configuration
        cp -r "$INSTALL_DIR/docker/rootfs/etc/nginx/*" /etc/nginx/ 2>/dev/null || true
        cp -r "$INSTALL_DIR/docker/rootfs/var/www/html/*" /var/www/html/ 2>/dev/null || true
        cp "$INSTALL_DIR/docker/rootfs/etc/letsencrypt.ini" /etc/letsencrypt.ini 2>/dev/null || true
        cp "$INSTALL_DIR/docker/rootfs/etc/logrotate.d/nginx-proxy-manager" /etc/logrotate.d/nginx-proxy-manager 2>/dev/null || true
        
        # Update Nginx config
        sed -i "s|\"version\": \"2.0.0\"|\"version\": \"$RELEASE\"|" "$INSTALL_DIR/backend/package.json"
        sed -i "s|\"version\": \"2.0.0\"|\"version\": \"$RELEASE\"|" "$INSTALL_DIR/frontend/package.json"
        sed -i "s+^daemon+#daemon+g" "$INSTALL_DIR/docker/rootfs/etc/nginx/nginx.conf"
        
        # Update nginx conf includes
        NGINX_CONFS=$(find "$INSTALL_DIR" -type f -name "*.conf" 2>/dev/null || true)
        for NGINX_CONF in $NGINX_CONFS; do
            sed -i "s+include conf.d+include /etc/nginx/conf.d+g" "$NGINX_CONF" 2>/dev/null || true
        done
        
        ln -sf /etc/nginx/nginx.conf /etc/nginx/conf/nginx.conf 2>/dev/null || true
        rm -f /etc/nginx/conf.d/dev.conf 2>/dev/null || true
        
        # Create resolver config
        echo resolver "$(awk '\''BEGIN{ORS=" "} $1=="nameserver" {print ($2 ~ ":")? "["$2"]": $2}'\'' /etc/resolv.conf);" > /etc/nginx/conf.d/include/resolvers.conf
        
        # Generate dummy certificate
        if [[ ! -f /data/nginx/dummycert.pem ]] || [[ ! -f /data/nginx/dummykey.pem ]]; then
            openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
                -subj "/O=Nginx Proxy Manager/OU=Dummy Certificate/CN=localhost" \
                -keyout /data/nginx/dummykey.pem \
                -out /data/nginx/dummycert.pem
        fi
        
        # Copy backend
        cp -r "$INSTALL_DIR/backend/*" /app/ 2>/dev/null || true
        
        # Build frontend
        cd "$INSTALL_DIR/frontend"
        # Replace node-sass with sass
        sed -E -i "s/\"node-sass\" *: *\"([^\"]*)\"/\"sass\": \"\1\"/g" package.json
        yarn install --network-timeout 600000
        yarn build
        cp -r "$INSTALL_DIR/frontend/dist/*" /app/frontend/ 2>/dev/null || true
        cp -r "$INSTALL_DIR/frontend/public/images/*" /app/frontend/images/ 2>/dev/null || true
        
        # Setup backend
        rm -rf /app/config/default.json
        if [[ ! -f /app/config/production.json ]]; then
            mkdir -p /app/config
            cat > /app/config/production.json <<EOF
{
  "database": {
    "engine": "knex-native",
    "knex": {
      "client": "sqlite3",
      "connection": {
        "filename": "/data/database.sqlite"
      }
    }
  }
}
EOF
        fi
        
        cd /app
        yarn install --network-timeout 600000
        
        # Update Certbot if exists
        if [[ -d /opt/certbot ]]; then
            /opt/certbot/bin/pip install --upgrade pip setuptools wheel
            /opt/certbot/bin/pip install --upgrade certbot certbot-dns-cloudflare
        fi
        
        # Update Nginx config for root user
        sed -i "s/user npm/user root/g; s/^pid/#pid/g" /usr/local/openresty/nginx/conf/nginx.conf
        sed -r -i "s/^([[:space:]]*)su npm npm/\1#su npm npm/g;" /etc/logrotate.d/nginx-proxy-manager 2>/dev/null || true
        
        # Create systemd service
        cat > /lib/systemd/system/npm.service <<EOF
[Unit]
Description=Nginx Proxy Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app
ExecStart=/usr/bin/node /app/index.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable and start services
        systemctl daemon-reload
        systemctl enable openresty
        systemctl enable npm
    '
    
    log_success "Nginx Proxy Manager installed successfully"
}

configure_nginxproxymanager() {
    local ctid=$1
    
    log_info "Starting Nginx Proxy Manager services..."
    
    # Start services
    pct exec "$ctid" -- bash -c '
        systemctl restart openresty
        systemctl restart npm
        sleep 3
    ' || {
        log_warning "Failed to start Nginx Proxy Manager services"
    }
    
    # Get container IP
    local container_ip
    container_ip=$(pct exec "$ctid" -- ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 || echo "N/A")
    
    log_success "Nginx Proxy Manager configured"
    log_info "Access Nginx Proxy Manager at: http://${container_ip}:81"
    log_info "Default login: admin@example.com / changeme"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    check_proxmox
    
    if [[ -z "${CT_ID:-}" ]]; then
        log_error "CT_ID not set. Please provide container ID."
        exit 1
    fi
    
    install_nginxproxymanager "$CT_ID"
    configure_nginxproxymanager "$CT_ID"
fi

