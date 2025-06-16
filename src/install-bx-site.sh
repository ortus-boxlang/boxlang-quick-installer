#!/bin/bash

# BoxLang Website Installer Script
# This script helps install and configure a BoxLang miniserver web application
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

set -e

###########################################################################
# Global Color Variables
###########################################################################
# Initialize colors globally so all functions can use them
setup_colors() {
	# Use colors, but only if connected to a terminal, and that terminal supports them.
	if which tput >/dev/null 2>&1; then
		ncolors=$(tput colors)
	fi
	if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
		RED="$(tput setaf 1)"
		GREEN="$(tput setaf 2)"
		YELLOW="$(tput setaf 3)"
		BLUE="$(tput setaf 4)"
		BOLD="$(tput bold)"
		NORMAL="$(tput sgr0)"
		MAGENTA="$(tput setaf 5)"
		CYAN="$(tput setaf 6)"
		WHITE="$(tput setaf 7)"
		BLACK="$(tput setaf 0)"
		UNDERLINE="$(tput smul)"
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		NORMAL=""
		MAGENTA=""
		CYAN=""
		WHITE=""
		BLACK=""
		UNDERLINE=""
	fi
}

# Initialize colors at script startup
setup_colors

# Legacy color variable for backward compatibility
NC="$NORMAL"

# Default values
DEFAULT_SITE_NAME="default"
DEFAULT_PORT="8080"
DEFAULT_HOST="localhost"
DEFAULT_REWRITES="yes"
DEFAULT_MIN_MEMORY="512m"
DEFAULT_MAX_MEMORY="512m"

# OS Detection
OS_TYPE=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="mac"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
else
    echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper functions
print_header() {
    printf "${BLUE}"
    printf "==================================================\n"
    printf "    BoxLang Website Installer Script v1.0.0\n"
    printf "==================================================\n"
    printf "${NORMAL}"
}

print_success() {
    printf "${GREEN}✓ $1${NORMAL}\n"
}

print_error() {
    printf "${RED}✗ $1${NORMAL}\n"
}

print_warning() {
    printf "${YELLOW}⚠ $1${NORMAL}\n"
}

print_info() {
    printf "${BLUE}ℹ $1${NORMAL}\n"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        INSTALL_TYPE="system"
        print_info "Running as root - using system installation paths"
    else
        INSTALL_TYPE="user"
        print_info "Running as user - using user installation paths"
    fi
}

# Get default webroot based on installation type
get_default_webroot() {
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        echo "/var/www/boxlang"
    else
        echo "$HOME/Sites/boxlang"
    fi
}

# Prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    echo -n -e "${YELLOW}$prompt [$default]: ${NC}"
    read -r input

    if [[ -z "$input" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Prompt for yes/no with default
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    while true; do
        if [[ "$default" == "yes" ]]; then
            echo -n -e "${YELLOW}$prompt [Y/n]: ${NC}"
        else
            echo -n -e "${YELLOW}$prompt [y/N]: ${NC}"
        fi

        read -r input

        if [[ -z "$input" ]]; then
            eval "$var_name=\"$default\""
            break
        elif [[ "$input" =~ ^[Yy]$ ]]; then
            eval "$var_name=\"yes\""
            break
        elif [[ "$input" =~ ^[Nn]$ ]]; then
            eval "$var_name=\"no\""
            break
        else
            print_error "Please enter y or n"
        fi
    done
}

# Validate port number
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "Invalid port number: $port"
        return 1
    fi

    # Check if port is in use
    if command_exists lsof; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $port is already in use"
            return 1
        fi
    fi

    return 0
}

# Validate memory value (e.g., 512m, 1g, 2048m)
validate_memory() {
    local memory="$1"
    if [[ "$memory" =~ ^[0-9]+[mMgG]?$ ]]; then
        return 0
    else
        print_error "Invalid memory format: $memory (use format like 512m, 1g, 2048m)"
        return 1
    fi
}

# Create directory if it doesn't exist
create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_success "Created directory: $dir"
    fi
}

# Generate control script
generate_control_script() {
    local script_path="$1"
    local site_name="$2"
    local webroot="$3"
    local host="$4"
    local port="$5"
    local rewrites="$6"
    local server_home="$7"
    local min_memory="$8"
    local max_memory="$9"

    cat > "$script_path" << EOF
#!/bin/bash

# BoxLang Website Control Script for: $site_name
# Generated by install-bx-website.sh

SITE_NAME="$site_name"
WEBROOT="$webroot"
HOST="$host"
PORT="$port"
REWRITES="$rewrites"
SERVER_HOME="$server_home"
MIN_MEMORY="$min_memory"
MAX_MEMORY="$max_memory"
PID_FILE="\$SERVER_HOME/\$SITE_NAME.pid"
LOG_FILE="\$SERVER_HOME/logs/\$SITE_NAME.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

start_server() {
    if [[ -f "\$PID_FILE" ]] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
        echo -e "\${YELLOW}Server '\$SITE_NAME' is already running (PID: \$(cat "\$PID_FILE"))\${NC}"
        return 1
    fi

    echo -e "\${GREEN}Starting BoxLang server '\$SITE_NAME'...\${NC}"

    # Create log directory
    mkdir -p "\$(dirname "\$LOG_FILE")"

    # Set JVM memory options
    export JAVA_OPTS="-Xms\$MIN_MEMORY -Xmx\$MAX_MEMORY"

    # Build command arguments
    ARGS=()
    ARGS+=("--webroot" "\$WEBROOT")
    ARGS+=("--host" "\$HOST")
    ARGS+=("--port" "\$PORT")
    ARGS+=("--serverHome" "\$SERVER_HOME")

    if [[ "\$REWRITES" == "yes" ]]; then
        ARGS+=("--rewrites")
    fi

    # Start the server in background
    nohup boxlang-miniserver "\${ARGS[@]}" > "\$LOG_FILE" 2>&1 &
    echo \$! > "\$PID_FILE"

    sleep 2

    if kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
        echo -e "\${GREEN}✓ Server '\$SITE_NAME' started successfully\${NC}"
        echo -e "\${GREEN}  URL: http://\$HOST:\$PORT\${NC}"
        echo -e "\${GREEN}  PID: \$(cat "\$PID_FILE")\${NC}"
        echo -e "\${GREEN}  Log: \$LOG_FILE\${NC}"
    else
        echo -e "\${RED}✗ Failed to start server '\$SITE_NAME'\${NC}"
        rm -f "\$PID_FILE"
        return 1
    fi
}

stop_server() {
    if [[ ! -f "\$PID_FILE" ]]; then
        echo -e "\${YELLOW}Server '\$SITE_NAME' is not running (no PID file)\${NC}"
        return 1
    fi

    local pid=\$(cat "\$PID_FILE")

    if ! kill -0 "\$pid" 2>/dev/null; then
        echo -e "\${YELLOW}Server '\$SITE_NAME' is not running (stale PID file)\${NC}"
        rm -f "\$PID_FILE"
        return 1
    fi

    echo -e "\${GREEN}Stopping BoxLang server '\$SITE_NAME' (PID: \$pid)...\${NC}"

    # Send TERM signal
    kill "\$pid"

    # Wait for process to stop
    local count=0
    while kill -0 "\$pid" 2>/dev/null && [ \$count -lt 30 ]; do
        sleep 1
        count=\$((count + 1))
    done

    if kill -0 "\$pid" 2>/dev/null; then
        echo -e "\${YELLOW}Process didn't stop gracefully, forcing termination...\${NC}"
        kill -9 "\$pid"
        sleep 1
    fi

    rm -f "\$PID_FILE"
    echo -e "\${GREEN}✓ Server '\$SITE_NAME' stopped\${NC}"
}

status_server() {
    if [[ ! -f "\$PID_FILE" ]]; then
        echo -e "\${RED}Server '\$SITE_NAME' is not running (no PID file)\${NC}"
        return 1
    fi

    local pid=\$(cat "\$PID_FILE")

    if kill -0 "\$pid" 2>/dev/null; then
        echo -e "\${GREEN}Server '\$SITE_NAME' is running\${NC}"
        echo -e "\${GREEN}  URL: http://\$HOST:\$PORT\${NC}"
        echo -e "\${GREEN}  PID: \$pid\${NC}"
        echo -e "\${GREEN}  Webroot: \$WEBROOT\${NC}"
        echo -e "\${GREEN}  Server Home: \$SERVER_HOME\${NC}"
        echo -e "\${GREEN}  Memory: \$MIN_MEMORY - \$MAX_MEMORY\${NC}"
        echo -e "\${GREEN}  Log: \$LOG_FILE\${NC}"
        return 0
    else
        echo -e "\${RED}Server '\$SITE_NAME' is not running (stale PID file)\${NC}"
        rm -f "\$PID_FILE"
        return 1
    fi
}

restart_server() {
    echo -e "\${GREEN}Restarting BoxLang server '\$SITE_NAME'...\${NC}"
    stop_server
    sleep 2
    start_server
}

show_logs() {
    if [[ -f "\$LOG_FILE" ]]; then
        tail -f "\$LOG_FILE"
    else
        echo -e "\${RED}Log file not found: \$LOG_FILE\${NC}"
        return 1
    fi
}

case "\$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        status_server
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the BoxLang server"
        echo "  stop    - Stop the BoxLang server"
        echo "  restart - Restart the BoxLang server"
        echo "  status  - Show server status"
        echo "  logs    - Show server logs (tail -f)"
        echo ""
        echo "Site: \$SITE_NAME"
        echo "URL:  http://\$HOST:\$PORT"
        exit 1
        ;;
esac
EOF

    chmod +x "$script_path"
}

# Generate systemd service (Linux)
generate_systemd_service() {
    local site_name="$1"
    local control_script="$2"
    local user="$3"

    local service_file="/etc/systemd/system/boxlang-$site_name.service"

    cat > "$service_file" << EOF
[Unit]
Description=BoxLang MiniServer - $site_name
After=network.target

[Service]
Type=forking
User=$user
ExecStart=$control_script start
ExecStop=$control_script stop
ExecReload=$control_script restart
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "Created systemd service: boxlang-$site_name"
}

# Generate launchd plist (macOS)
generate_launchd_plist() {
    local site_name="$1"
    local control_script="$2"
    local user="$3"

    local plist_file="/Library/LaunchDaemons/com.boxlang.$site_name.plist"

    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.boxlang.$site_name</string>
    <key>ProgramArguments</key>
    <array>
        <string>$control_script</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>$user</string>
</dict>
</plist>
EOF

    launchctl load "$plist_file"
    print_success "Created launchd service: com.boxlang.$site_name"
}

# Setup auto-start
setup_autostart() {
    local site_name="$1"
    local control_script="$2"

    if [[ "$INSTALL_TYPE" == "system" ]]; then
        local user
        if [[ "$OS_TYPE" == "linux" ]]; then
            user="www-data"
            if ! id "$user" >/dev/null 2>&1; then
                user="nobody"
            fi
        else
            user="$(whoami)"
        fi

        if [[ "$OS_TYPE" == "linux" ]]; then
            generate_systemd_service "$site_name" "$control_script" "$user"
            echo -e "${GREEN}To enable auto-start: sudo systemctl enable boxlang-$site_name${NC}"
        elif [[ "$OS_TYPE" == "mac" ]]; then
            generate_launchd_plist "$site_name" "$control_script" "$user"
            echo -e "${GREEN}Service will start automatically on boot${NC}"
        fi
    else
        print_info "Auto-start setup is only available for system installations"
        print_info "You can manually add '$control_script start' to your startup scripts"
    fi
}

# Show help information
show_help() {
    printf "${GREEN}🌐 BoxLang Website Installer Script v1.0.0${NC}\n\n"
    printf "${YELLOW}This script helps you install and configure a BoxLang miniserver web application.${NC}\n\n"
    printf "${BOLD}Usage:${NC}\n"
    printf "  install-bx-site.sh [options]\n"
    printf "  install-bx-site.sh --help\n\n"
    printf "${BOLD}Options:${NC}\n"
    printf "  --help, -h        Show this help message and exit\n\n"
    printf "${BOLD}What this installer does:${NC}\n"
    printf "  ✅ Interactive configuration wizard\n"
    printf "  ✅ Automatic directory structure creation\n"
    printf "  ✅ Memory configuration (JVM -Xms/-Xmx)\n"
    printf "  ✅ URL rewrites support\n"
    printf "  ✅ Host binding options (localhost/0.0.0.0)\n"
    printf "  ✅ Port configuration with validation\n"
    printf "  ✅ Control script generation for start/stop/status/logs\n"
    printf "  ✅ Auto-start service setup (systemd/launchd)\n"
    printf "  ✅ Welcome page with BoxLang branding\n\n"
    printf "${BOLD}Installation Paths:${NC}\n"
    printf "  📁 User installations: ~/Sites/boxlang\n"
    printf "  📁 System installations: /var/www/boxlang\n\n"
    printf "${BOLD}Default Server Settings:${NC}\n"
    printf "  🌐 Host: localhost\n"
    printf "  🔌 Port: 8080\n"
    printf "  💾 Memory: 512m (min/max)\n"
    printf "  🔗 Rewrites: Enabled\n"
    printf "  📝 Site name: default\n\n"
    printf "${BOLD}Generated Control Script Commands:${NC}\n"
    printf "  🚀 ${GREEN}start${NC}         Start the BoxLang server\n"
    printf "  🛑 ${GREEN}stop${NC}          Stop the BoxLang server\n"
    printf "  🔄 ${GREEN}restart${NC}       Restart the BoxLang server\n"
    printf "  📊 ${GREEN}status${NC}        Show server status\n"
    printf "  📋 ${GREEN}logs${NC}          Show server logs (tail -f)\n\n"
    printf "${BOLD}Examples:${NC}\n"
    printf "  install-bx-site.sh            # Interactive installation\n"
    printf "  install-bx-site.sh --help     # Show this help\n\n"
    printf "${BOLD}Requirements:${NC}\n"
    printf "  - BoxLang installed with boxlang-miniserver command available\n"
    printf "  - Bash shell\n"
    printf "  - Write permissions to target directories\n\n"
    printf "${BOLD}More Information:${NC}\n"
    printf "  📖 Documentation: https://boxlang.ortusbooks.com/\n"
    printf "  💬 Community: https://community.ortussolutions.com/c/boxlang/42\n"
    printf "  💾 GitHub: https://github.com/ortus-boxlang\n"
}

# Main installation function
main() {
    # Handle command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac

    print_header

    # Check dependencies
    if ! command_exists boxlang-miniserver; then
        print_error "boxlang-miniserver not found. Please install BoxLang first."
        exit 1
    fi

    check_root

    echo -e "${BLUE}This script will help you set up a BoxLang miniserver website.${NC}"
    echo ""

    # Get configuration from user
    local site_name
    prompt_with_default "Site name" "$DEFAULT_SITE_NAME" "site_name"

    # Validate site name
    if [[ ! "$site_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid site name. Use only letters, numbers, hyphens, and underscores."
        exit 1
    fi

    local default_webroot
    default_webroot=$(get_default_webroot)

    local webroot
    prompt_with_default "Webroot directory" "$default_webroot" "webroot"

    # Expand tilde
    webroot="${webroot/#\~/$HOME}"

    local host_choice
    echo -e "${YELLOW}Bind to:${NC}"
    echo "  1) localhost (local access only)"
    echo "  2) 0.0.0.0 (all interfaces)"
    echo -n -e "${YELLOW}Choose [1]: ${NC}"
    read -r host_choice

    local host
    if [[ "$host_choice" == "2" ]]; then
        host="0.0.0.0"
    else
        host="localhost"
    fi

    local port
    while true; do
        prompt_with_default "Port" "$DEFAULT_PORT" "port"
        if validate_port "$port"; then
            break
        fi
    done

    local enable_rewrites
    prompt_yes_no "Enable URL rewrites" "$DEFAULT_REWRITES" "enable_rewrites"

    local min_memory
    while true; do
        prompt_with_default "Minimum memory (JVM -Xms)" "$DEFAULT_MIN_MEMORY" "min_memory"
        if validate_memory "$min_memory"; then
            break
        fi
    done

    local max_memory
    while true; do
        prompt_with_default "Maximum memory (JVM -Xmx)" "$DEFAULT_MAX_MEMORY" "max_memory"
        if validate_memory "$max_memory"; then
            break
        fi
    done

    local default_server_home="$HOME/.boxlang/servers/$site_name"
    if [[ "$INSTALL_TYPE" == "system" ]]; then
        default_server_home="/var/lib/boxlang/servers/$site_name"
    fi

    local server_home
    prompt_with_default "Server home directory" "$default_server_home" "server_home"

    # Expand tilde
    server_home="${server_home/#\~/$HOME}"

    echo ""
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo "  Site name: $site_name"
    echo "  Webroot: $webroot"
    echo "  Host: $host"
    echo "  Port: $port"
    echo "  Rewrites: $enable_rewrites"
    echo "  Min memory: $min_memory"
    echo "  Max memory: $max_memory"
    echo "  Server home: $server_home"
    echo ""

    local confirm
    prompt_yes_no "Proceed with installation" "yes" "confirm"

    if [[ "$confirm" != "yes" ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    echo ""
    print_info "Starting installation..."

    # Create directories
    create_directory "$webroot"
    create_directory "$server_home"
    create_directory "$server_home/logs"    # Create a simple index file if webroot is empty
    if [[ ! -f "$webroot/index.bxm" && ! -f "$webroot/index.cfm" && ! -f "$webroot/index.html" ]]; then
        # Get the directory where this script is located
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local template_file="$script_dir/assets/index.bxm"

        if [[ -f "$template_file" ]]; then
            cp "$template_file" "$webroot/index.bxm"
            print_success "Created welcome page: $webroot/index.bxm"

            # Copy image assets for the welcome page
            local assets_dir="$script_dir/assets"
            if [[ -f "$assets_dir/boxlang.jpeg" ]]; then
                cp "$assets_dir/boxlang.jpeg" "$webroot/"
                print_success "Copied BoxLang icon to webroot"
            fi
            if [[ -f "$assets_dir/boxlang-miniserver.png" ]]; then
                cp "$assets_dir/boxlang-miniserver.png" "$webroot/"
                print_success "Copied BoxLang MiniServer logo to webroot"
            fi
        else
            print_warning "Template file not found: $template_file"
            print_info "You can create your own index.bxm file in the webroot"
        fi
    fi

    # Generate control script
    local control_script="$server_home/control.sh"
    generate_control_script "$control_script" "$site_name" "$webroot" "$host" "$port" "$enable_rewrites" "$server_home" "$min_memory" "$max_memory"
    print_success "Created control script: $control_script"

    # Ask about auto-start
    local setup_autostart_choice
    prompt_yes_no "Setup auto-start on boot" "no" "setup_autostart_choice"

    if [[ "$setup_autostart_choice" == "yes" ]]; then
        setup_autostart "$site_name" "$control_script"
    fi

    echo ""
    print_success "BoxLang website '$site_name' installed successfully!"
    echo ""
    echo -e "${GREEN}Control Commands:${NC}"
    echo "  Start:   $control_script start"
    echo "  Stop:    $control_script stop"
    echo "  Status:  $control_script status"
    echo "  Restart: $control_script restart"
    echo "  Logs:    $control_script logs"
    echo ""
    echo -e "${GREEN}Website URL: http://$host:$port${NC}"
    echo ""

    # Ask if user wants to start the server now
    local start_now
    prompt_yes_no "Start the server now" "yes" "start_now"

    if [[ "$start_now" == "yes" ]]; then
        echo ""
        "$control_script" start
    fi
}

# Run main function
main "$@"
