#!/system/bin/sh

readonly BOX_DIR="/data/adb/box"
readonly CONF_DIR="$BOX_DIR/conf"
readonly RUN_DIR="$BOX_DIR/run"

readonly USER_CONFIG_FILE="$CONF_DIR/settings.ini"

readonly DEFAULT_CORE_USER_GROUP="root:net_admin"
readonly DEFAULT_ROUTING_MARK=""
readonly DEFAULT_PROXY_TCP_PORT="1536"
readonly DEFAULT_PROXY_UDP_PORT="1536"
readonly DEFAULT_PROXY_MODE=0

readonly DEFAULT_DNS_HIJACK_ENABLE=1
readonly DEFAULT_DNS_PORT="1053"

readonly DEFAULT_MOBILE_INTERFACE="rmnet_data+"
readonly DEFAULT_WIFI_INTERFACE="wlan0"
readonly DEFAULT_HOTSPOT_INTERFACE="wlan2"
readonly DEFAULT_USB_INTERFACE="rndis+"

readonly DEFAULT_PROXY_MOBILE=1
readonly DEFAULT_PROXY_WIFI=1
readonly DEFAULT_PROXY_HOTSPOT=0
readonly DEFAULT_PROXY_USB=0
readonly DEFAULT_PROXY_TCP=1
readonly DEFAULT_PROXY_UDP=1
readonly DEFAULT_PROXY_IPV6=0

readonly DEFAULT_MARK_VALUE=20
readonly DEFAULT_MARK_VALUE6=25
readonly DEFAULT_TABLE_ID=2025

readonly DEFAULT_APP_PROXY_ENABLE=0
readonly DEFAULT_PROXY_APPS_LIST=""
readonly DEFAULT_BYPASS_APPS_LIST=""
readonly DEFAULT_APP_PROXY_MODE="blacklist"

readonly DEFAULT_BYPASS_CN_IP=0
readonly DEFAULT_CN_IP_FILE="$RUN_DIR/cn.zone"
readonly DEFAULT_CN_IPV6_FILE="$RUN_DIR/cn_ipv6.zone"
readonly DEFAULT_CN_IP_URL="https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt"
readonly DEFAULT_CN_IPV6_URL="https://ispip.clang.cn/all_cn_ipv6.txt"

readonly DEFAULT_MAC_FILTER_ENABLE=0
readonly DEFAULT_PROXY_MACS_LIST=""
readonly DEFAULT_BYPASS_MACS_LIST=""
readonly DEFAULT_MAC_PROXY_MODE="blacklist"

readonly DEFAULT_DRY_RUN=0
readonly DEFAULT_LOG_LEVEL=1

log() {
    local level="$1"
    local message="$2"
    local timestamp
    local level_score=0
    local current_log_level="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"

    case "$level" in
        Debug) level_score=0 ;;
        Info)  level_score=1 ;;
        Warn)  level_score=2 ;;
        Error) level_score=3 ;;
        *)     level_score=1 ;;
    esac

    # Early return if log level filters this message
    [ "$level_score" -lt "$current_log_level" ] && return 0

    timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    
    # Check if output is a terminal (for color support)
    if [ -t 1 ]; then
        case "$level" in
            Debug) printf "\033[0;30m%s [%s]: %s\033[0m\n" "$timestamp" "$level" "$message" >&2 ;;
            Info)  printf "\033[0;36m%s [%s]: %s\033[0m\n" "$timestamp" "$level" "$message" >&2 ;;
            Warn)  printf "\033[1;33m%s [%s]: %s\033[0m\n" "$timestamp" "$level" "$message" >&2 ;;
            Error) printf "\033[1;31m%s [%s]: %s\033[0m\n" "$timestamp" "$level" "$message" >&2 ;;
            *)     printf "%s [%s]: %s\n" "$timestamp" "$level" "$message" >&2 ;;
        esac
    else
        printf "%s [%s]: %s\n" "$timestamp" "$level" "$message" >&2
    fi
}

load_config() {
    log Info "Initializing configuration..."

    if [ -f "$USER_CONFIG_FILE" ]; then
        log Info "Loading settings from: $USER_CONFIG_FILE"
        
        set -a
        source "$USER_CONFIG_FILE"
        set +a
    else
        log Warn "Settings file not found at $USER_CONFIG_FILE. Using internal defaults."
    fi
    
    # Log level configuration
    LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
    log Debug "LOG_LEVEL: $LOG_LEVEL"
    
    # Dry-run mode (disabled by default)
    DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"
    log Debug "DRY_RUN: $DRY_RUN"

    # Proxy core configuration
    CORE_USER_GROUP="${CORE_USER_GROUP:-$DEFAULT_CORE_USER_GROUP}"
    log Debug "CORE_USER_GROUP: $CORE_USER_GROUP"

    ROUTING_MARK="${ROUTING_MARK:-$DEFAULT_ROUTING_MARK}"
    log Debug "ROUTING_MARK: $ROUTING_MARK"

    PROXY_TCP_PORT="${PROXY_TCP_PORT:-$DEFAULT_PROXY_TCP_PORT}"
    log Debug "PROXY_TCP_PORT: $PROXY_TCP_PORT"

    PROXY_UDP_PORT="${PROXY_UDP_PORT:-$DEFAULT_PROXY_UDP_PORT}"
    log Debug "PROXY_UDP_PORT: $PROXY_UDP_PORT"

    # Proxy mode: 0=auto, 1=force TPROXY, 2=force REDIRECT
    PROXY_MODE="${PROXY_MODE:-$DEFAULT_PROXY_MODE}"
    log Debug "PROXY_MODE: $PROXY_MODE"

    # DNS configuration
    DNS_HIJACK_ENABLE="${DNS_HIJACK_ENABLE:-$DEFAULT_DNS_HIJACK_ENABLE}"
    log Debug "DNS_HIJACK_ENABLE: $DNS_HIJACK_ENABLE"

    DNS_PORT="${DNS_PORT:-$DEFAULT_DNS_PORT}"
    log Debug "DNS_PORT: $DNS_PORT"

    # Interface definitions
    MOBILE_INTERFACE="${MOBILE_INTERFACE:-$DEFAULT_MOBILE_INTERFACE}"
    log Debug "MOBILE_INTERFACE: $MOBILE_INTERFACE"

    WIFI_INTERFACE="${WIFI_INTERFACE:-$DEFAULT_WIFI_INTERFACE}"
    log Debug "WIFI_INTERFACE: $WIFI_INTERFACE"

    HOTSPOT_INTERFACE="${HOTSPOT_INTERFACE:-$DEFAULT_HOTSPOT_INTERFACE}"
    log Debug "HOTSPOT_INTERFACE: $HOTSPOT_INTERFACE"

    USB_INTERFACE="${USB_INTERFACE:-$DEFAULT_USB_INTERFACE}"
    log Debug "USB_INTERFACE: $USB_INTERFACE"

    # Proxy switches
    PROXY_MOBILE="${PROXY_MOBILE:-$DEFAULT_PROXY_MOBILE}"
    log Debug "PROXY_MOBILE: $PROXY_MOBILE"

    PROXY_WIFI="${PROXY_WIFI:-$DEFAULT_PROXY_WIFI}"
    log Debug "PROXY_WIFI: $PROXY_WIFI"

    PROXY_HOTSPOT="${PROXY_HOTSPOT:-$DEFAULT_PROXY_HOTSPOT}"
    log Debug "PROXY_HOTSPOT: $PROXY_HOTSPOT"

    PROXY_USB="${PROXY_USB:-$DEFAULT_PROXY_USB}"
    log Debug "PROXY_USB: $PROXY_USB"

    PROXY_TCP="${PROXY_TCP:-$DEFAULT_PROXY_TCP}"
    log Debug "PROXY_TCP: $PROXY_TCP"

    PROXY_UDP="${PROXY_UDP:-$DEFAULT_PROXY_UDP}"
    log Debug "PROXY_UDP: $PROXY_UDP"

    PROXY_IPV6="${PROXY_IPV6:-$DEFAULT_PROXY_IPV6}"
    log Debug "PROXY_IPV6: $PROXY_IPV6"

    # Mark values
    MARK_VALUE="${MARK_VALUE:-$DEFAULT_MARK_VALUE}"
    log Debug "MARK_VALUE: $MARK_VALUE"

    MARK_VALUE6="${MARK_VALUE6:-$DEFAULT_MARK_VALUE6}"
    log Debug "MARK_VALUE6: $MARK_VALUE6"

    # Routing table ID
    TABLE_ID="${TABLE_ID:-$DEFAULT_TABLE_ID}"
    log Debug "TABLE_ID: $TABLE_ID"

    # Per-app proxy
    APP_PROXY_ENABLE="${APP_PROXY_ENABLE:-$DEFAULT_APP_PROXY_ENABLE}"
    log Debug "APP_PROXY_ENABLE: $APP_PROXY_ENABLE"

    PROXY_APPS_LIST="${PROXY_APPS_LIST:-$DEFAULT_PROXY_APPS_LIST}"
    log Debug "PROXY_APPS_LIST: $PROXY_APPS_LIST"

    BYPASS_APPS_LIST="${BYPASS_APPS_LIST:-$DEFAULT_BYPASS_APPS_LIST}"
    log Debug "BYPASS_APPS_LIST: $BYPASS_APPS_LIST"

    APP_PROXY_MODE="${APP_PROXY_MODE:-$DEFAULT_APP_PROXY_MODE}"
    log Debug "APP_PROXY_MODE: $APP_PROXY_MODE"

    # CN IP bypass
    BYPASS_CN_IP="${BYPASS_CN_IP:-$DEFAULT_BYPASS_CN_IP}"
    log Debug "BYPASS_CN_IP: $BYPASS_CN_IP"

    CN_IP_FILE="${CN_IP_FILE:-$DEFAULT_CN_IP_FILE}"
    log Debug "CN_IP_FILE: $CN_IP_FILE"

    CN_IPV6_FILE="${CN_IPV6_FILE:-$DEFAULT_CN_IPV6_FILE}"
    log Debug "CN_IPV6_FILE: $CN_IPV6_FILE"

    CN_IP_URL="${CN_IP_URL:-$DEFAULT_CN_IP_URL}"
    log Debug "CN_IP_URL: $CN_IP_URL"

    CN_IPV6_URL="${CN_IPV6_URL:-$DEFAULT_CN_IPV6_URL}"
    log Debug "CN_IPV6_URL: $CN_IPV6_URL"

    # MAC address filtering
    MAC_FILTER_ENABLE="${MAC_FILTER_ENABLE:-$DEFAULT_MAC_FILTER_ENABLE}"
    log Debug "MAC_FILTER_ENABLE: $MAC_FILTER_ENABLE"

    PROXY_MACS_LIST="${PROXY_MACS_LIST:-$DEFAULT_PROXY_MACS_LIST}"
    log Debug "PROXY_MACS_LIST: $PROXY_MACS_LIST"

    BYPASS_MACS_LIST="${BYPASS_MACS_LIST:-$DEFAULT_BYPASS_MACS_LIST}"
    log Debug "BYPASS_MACS_LIST: $BYPASS_MACS_LIST"

    MAC_PROXY_MODE="${MAC_PROXY_MODE:-$DEFAULT_MAC_PROXY_MODE}"
    log Debug "MAC_PROXY_MODE: $MAC_PROXY_MODE"

    log Info "Configuration loading completed"
}

validate_config() {
    log Debug "Validating configuration..."

    if ! echo "$PROXY_TCP_PORT" | grep -E '^[0-9]+$' > /dev/null || [ "$PROXY_TCP_PORT" -lt 1 ] || [ "$PROXY_TCP_PORT" -gt 65535 ]; then
        log Error "Invalid PROXY_TCP_PORT: $PROXY_TCP_PORT"
        return 1
    fi

    if ! echo "$PROXY_UDP_PORT" | grep -E '^[0-9]+$' > /dev/null || [ "$PROXY_UDP_PORT" -lt 1 ] || [ "$PROXY_UDP_PORT" -gt 65535 ]; then
        log Error "Invalid PROXY_UDP_PORT: $PROXY_UDP_PORT"
        return 1
    fi

    if ! echo "$PROXY_MODE" | grep -E '^[0-2]$' > /dev/null; then
        log Error "Invalid PROXY_MODE: $PROXY_MODE (must be 0=auto, 1=force TPROXY, 2=force REDIRECT)"
        return 1
    fi

    if ! echo "$DNS_HIJACK_ENABLE" | grep -E '^[0-2]$' > /dev/null; then
        log Error "Invalid DNS_HIJACK_ENABLE: $DNS_HIJACK_ENABLE (must be 0=disabled, 1=tproxy, 2=redirect)"
        return 1
    fi

    if ! echo "$DNS_PORT" | grep -E '^[0-9]+$' > /dev/null || [ "$DNS_PORT" -lt 1 ] || [ "$DNS_PORT" -gt 65535 ]; then
        log Error "Invalid DNS_PORT: $DNS_PORT"
        return 1
    fi

    if ! echo "$MARK_VALUE" | grep -E '^[0-9]+$' > /dev/null || [ "$MARK_VALUE" -lt 1 ] || [ "$MARK_VALUE" -gt 2147483647 ]; then
        log Error "Invalid MARK_VALUE: $MARK_VALUE"
        return 1
    fi

    if ! echo "$MARK_VALUE6" | grep -E '^[0-9]+$' > /dev/null || [ "$MARK_VALUE6" -lt 1 ] || [ "$MARK_VALUE6" -gt 2147483647 ]; then
        log Error "Invalid MARK_VALUE6: $MARK_VALUE6"
        return 1
    fi

    if ! echo "$TABLE_ID" | grep -E '^[0-9]+$' > /dev/null || [ "$TABLE_ID" -lt 1 ] || [ "$TABLE_ID" -gt 65535 ]; then
        log Error "Invalid TABLE_ID: $TABLE_ID"
        return 1
    fi

    case "$CORE_USER_GROUP" in
        *:*)
            CORE_USER=$(echo "$CORE_USER_GROUP" | cut -d: -f1)
            CORE_GROUP=$(echo "$CORE_USER_GROUP" | cut -d: -f2)
            log Debug "Parsed user:group as '$CORE_USER:$CORE_GROUP'"
            ;;
        *)
            CORE_USER="root"
            CORE_GROUP="net_admin"
            log Debug "Using default user:group '$CORE_USER:$CORE_GROUP'"
            ;;
    esac

    if [ -z "$CORE_USER" ] || [ -z "$CORE_GROUP" ]; then
        log Warn "Empty user or group detected, using defaults"
        CORE_USER="root"
        CORE_GROUP="net_admin"
    fi

    log Info "Final user:group configuration: '$CORE_USER:$CORE_GROUP'"

    case "$APP_PROXY_MODE" in
        blacklist | whitelist) ;;
        *)
            log Error "Invalid APP_PROXY_MODE: $APP_PROXY_MODE"
            return 1
            ;;
    esac

    case "$MAC_PROXY_MODE" in
        blacklist | whitelist) ;;
        *)
            log Error "Invalid MAC_PROXY_MODE: $MAC_PROXY_MODE"
            return 1
            ;;
    esac

    log Debug "Configuration validation passed"
    return 0
}

check_root() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] Skip root check"
        return 0
    fi
    if [ "$(id -u 2> /dev/null || echo 1)" != "0" ]; then
        log Error "Must run with root privileges"
        exit 1
    fi
}

check_dependencies() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] Skip dependency check"
        return 0
    fi

    export PATH="$PATH:/data/data/com.termux/files/usr/bin"

    local missing=""
    local required_commands="ip iptables curl"
    local cmd

    for cmd in $required_commands; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log Error "Missing required commands: $missing"
        log Info "Check PATH: $PATH"
        exit 1
    fi
}

check_kernel_feature() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] Skip kernel feature check for $1"
        return 0
    fi

    local feature="$1"
    local config_name="CONFIG_${feature}"

    if [ -f /proc/config.gz ]; then
        if zcat /proc/config.gz 2> /dev/null | grep -qE "^${config_name}=[ym]$"; then
            log Debug "Kernel feature $feature is enabled"
            return 0
        else
            log Debug "Kernel feature $feature is disabled or not found"
            return 1
        fi
    else
        log Debug "Cannot check kernel feature $feature: /proc/config.gz not available"
        return 1
    fi
}

check_tproxy_support() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] TPROXY support check skipped"
        return 0
    fi

    if check_kernel_feature "NETFILTER_XT_TARGET_TPROXY"; then
        log Debug "Kernel TPROXY support confirmed"
        return 0
    else
        log Debug "Kernel TPROXY support not available"
        return 1
    fi
}

# Unified command wrapper functions
run_ipt_command() {
    local cmd="$1"
    shift
    local args="$*"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] $cmd $args"
        return 0
    else
        command $cmd -w 100 $args
    fi
}

iptables() {
    run_ipt_command iptables "$@"
}

ip6tables() {
    run_ipt_command ip6tables "$@"
}

ip_rule() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip rule $*"
        return 0
    else
        command ip rule "$@"
    fi
}

ip6_rule() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip -6 rule $*"
        return 0
    else
        command ip -6 rule "$@"
    fi
}

ip_route() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip route $*"
        return 0
    else
        command ip route "$@"
    fi
}

ip6_route() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip -6 route $*"
        return 0
    else
        command ip -6 route "$@"
    fi
}

get_package_uid() {
    local pkg="$1"
    local line
    local uid
    if [ ! -r /data/system/packages.list ]; then
        log Debug "Cannot read /data/system/packages.list"
        return 1
    fi
    line=$(grep -m1 "^${pkg}[[:space:]]" /data/system/packages.list 2> /dev/null || true)
    if [ -z "$line" ]; then
        log Debug "Package not found in packages.list: $pkg"
        return 1
    fi

    uid=$(echo "$line" | awk '{print $2}' 2> /dev/null || true)
    case "$uid" in
        '' | *[!0-9]*)
            uid=$(echo "$line" | awk '{print $(NF-1)}' 2> /dev/null || true)
            ;;
    esac
    case "$uid" in
        '' | *[!0-9]*)
            log Debug "Invalid UID format for package: $pkg"
            return 1
            ;;
        *)
            echo "$uid"
            return 0
            ;;
    esac
}

find_packages_uid() {
    local out
    local token
    local uid_base
    local final_uid
    # shellcheck disable=SC2048
    for token in $*; do
        local user_prefix=0
        local package="$token"
        case "$token" in
            *:*)
                user_prefix=$(echo "$token" | cut -d: -f1)
                package=$(echo "$token" | cut -d: -f2-)
                case "$user_prefix" in
                    '' | *[!0-9]*)
                        log Warn "Invalid user prefix in token: $token, using 0"
                        user_prefix=0
                        ;;
                esac
                ;;
        esac
        if uid_base=$(get_package_uid "$package" 2> /dev/null); then
            final_uid=$((user_prefix * 100000 + uid_base))
            out="$out $final_uid"
            log Debug "Resolved package $token to UID $final_uid"
        else
            log Warn "Failed to resolve UID for package: $package"
        fi
    done
    echo "$out" | awk '{$1=$1;print}'
}

safe_chain_exists() {
    local family="$1"
    local table="$2"
    local chain="$3"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        cmd="ip6tables"
    fi

    if $cmd -t "$table" -L "$chain" > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

safe_chain_create() {
    local family="$1"
    local table="$2"
    local chain="$3"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        cmd="ip6tables"
    fi

    if [ "$DRY_RUN" -eq 1 ] || ! safe_chain_exists "$family" "$table" "$chain"; then
        $cmd -t "$table" -N "$chain"
    fi

    $cmd -t "$table" -F "$chain"
}

download_cn_ip_list() {
    if [ "$BYPASS_CN_IP" -eq 0 ]; then
        log Debug "CN IP bypass is disabled, skipping download"
        return 0
    fi

    log Info "Checking/Downloading China mainland IP list to $CN_IP_FILE"

    # Re-download if file doesn't exist or is older than 7 days
    if [ ! -f "$CN_IP_FILE" ] || [ "$(find "$CN_IP_FILE" -mtime +7 2> /dev/null)" ]; then
        log Info "Fetching latest China IP list from $CN_IP_URL"
        if [ "$DRY_RUN" -eq 1 ]; then
            log Debug "[DRY-RUN] curl -fsSL --connect-timeout 10 --retry 3 $CN_IP_URL -o $CN_IP_FILE.tmp"
        else
            if ! curl -fsSL --connect-timeout 10 --retry 3 \
                "$CN_IP_URL" \
                -o "$CN_IP_FILE.tmp"; then
                log Error "Failed to download China IP list"
                rm -f "$CN_IP_FILE.tmp"
                return 1
            fi
        fi
        if [ "$DRY_RUN" -eq 0 ]; then
            mv "$CN_IP_FILE.tmp" "$CN_IP_FILE"
        fi
        log Info "China IP list saved to $CN_IP_FILE"
    else
        log Debug "Using existing China IP list: $CN_IP_FILE"
    fi

    if [ "$PROXY_IPV6" -eq 1 ]; then
        log Info "Checking/Downloading China mainland IPv6 list to $CN_IPV6_FILE"

        if [ ! -f "$CN_IPV6_FILE" ] || [ "$(find "$CN_IPV6_FILE" -mtime +7 2> /dev/null)" ]; then
            log Info "Fetching latest China IPv6 list from $CN_IPV6_URL"
            if [ "$DRY_RUN" -eq 1 ]; then
                log Debug "[DRY-RUN] curl -fsSL --connect-timeout 10 --retry 3 $CN_IPV6_URL -o $CN_IPV6_FILE.tmp"
            else
                if ! curl -fsSL --connect-timeout 10 --retry 3 \
                    "$CN_IPV6_URL" \
                    -o "$CN_IPV6_FILE.tmp"; then
                    log Error "Failed to download China IPv6 list"
                    rm -f "$CN_IPV6_FILE.tmp"
                    return 1
                fi
            fi
            if [ "$DRY_RUN" -eq 0 ]; then
                mv "$CN_IPV6_FILE.tmp" "$CN_IPV6_FILE"
            fi
            log Info "China IPv6 list saved to $CN_IPV6_FILE"
        else
            log Debug "Using existing China IPv6 list: $CN_IPV6_FILE"
        fi
    fi
}

setup_cn_ipset() {
    [ "$BYPASS_CN_IP" -eq 0 ] && {
        log Debug "CN IP bypass is disabled, skipping ipset setup"
        return 0
    }

    command -v ipset >/dev/null 2>&1 || {
        log Error "ipset not found. Cannot bypass CN IPs"
        return 1
    }

    log Info "Setting up ipset for China mainland IPs"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ipset destroy cnip"
        log Debug "[DRY-RUN] ipset destroy cnip6"
    else
        ipset destroy cnip 2>/dev/null || true
        ipset destroy cnip6 2>/dev/null || true
    fi

    # Setup IPv4 ipset
    if [ -f "$CN_IP_FILE" ] && [ -s "$CN_IP_FILE" ]; then
        local ipv4_count
        ipv4_count=$(wc -l < "$CN_IP_FILE" 2>/dev/null || echo "0")
        log Debug "Loading $ipv4_count IPv4 CIDR entries from $CN_IP_FILE"

        if [ "$DRY_RUN" -eq 1 ]; then
            log Debug "[DRY-RUN] Would load $ipv4_count IPv4 CIDR entries via ipset restore"
        else
            local temp_file
            temp_file=$(mktemp) || {
                log Error "Failed to create temporary file"
                return 1
            }
            
            {
                echo "create cnip hash:net family inet hashsize 8192 maxelem 65536"
                awk '!/^[[:space:]]*#/ && NF > 0 {printf "add cnip %s\n", $0}' "$CN_IP_FILE"
            } > "$temp_file"

            if ipset restore -f "$temp_file" 2>/dev/null; then
                log Info "Successfully loaded $ipv4_count IPv4 CIDR entries"
            else
                log Error "Failed to create ipset 'cnip' or load IPv4 CIDR entries"
                rm -f "$temp_file"
                return 1
            fi
            rm -f "$temp_file"
        fi
    else
        log Warn "CN IP file not found or empty: $CN_IP_FILE"
        return 1
    fi

    log Info "ipset 'cnip' loaded with China mainland IPs"

    # Setup IPv6 ipset if enabled
    if [ "$PROXY_IPV6" -eq 1 ] && [ -f "$CN_IPV6_FILE" ] && [ -s "$CN_IPV6_FILE" ]; then
        local ipv6_count
        ipv6_count=$(wc -l < "$CN_IPV6_FILE" 2>/dev/null || echo "0")
        log Debug "Loading $ipv6_count IPv6 CIDR entries from $CN_IPV6_FILE"

        if [ "$DRY_RUN" -eq 1 ]; then
            log Debug "[DRY-RUN] Would load $ipv6_count IPv6 CIDR entries via ipset restore"
        else
            local temp_file6
            temp_file6=$(mktemp) || {
                log Error "Failed to create temporary file for IPv6"
                return 0  # Don't fail on IPv6 error
            }
            
            {
                echo "create cnip6 hash:net family inet6 hashsize 8192 maxelem 65536"
                awk '!/^[[:space:]]*#/ && NF > 0 {printf "add cnip6 %s\n", $0}' "$CN_IPV6_FILE"
            } > "$temp_file6"

            if ipset restore -f "$temp_file6" 2>/dev/null; then
                log Info "Successfully loaded $ipv6_count IPv6 CIDR entries"
            else
                log Error "Failed to create ipset 'cnip6' or load IPv6 CIDR entries"
            fi
            rm -f "$temp_file6"
        fi
        log Info "ipset 'cnip6' loaded with China mainland IPv6 IPs"
    fi

    return 0
}

# Unified setup function for both IPv4 and IPv6 with mode selection
setup_proxy_chain() {
    local family="$1"
    local mode="$2" # tproxy or redirect
    local suffix=""
    local mark="$MARK_VALUE"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        mark="$MARK_VALUE6"
        cmd="ip6tables"
    fi

    # Set mode name for logging
    local mode_name="$mode"
    if [ "$mode" = "tproxy" ]; then
        mode_name="TPROXY"
    else
        mode_name="REDIRECT"
    fi

    log Info "Setting up $mode_name chains for IPv${family}"

    # Define chains based on family
    local chains=""
    if [ "$family" = "6" ]; then
        chains="PROXY_PREROUTING6 PROXY_OUTPUT6 BYPASS_IP6 BYPASS_INTERFACE6 PROXY_INTERFACE6 DNS_HIJACK_PRE6 DNS_HIJACK_OUT6 APP_CHAIN6 MAC_CHAIN6"
    else
        chains="PROXY_PREROUTING PROXY_OUTPUT BYPASS_IP BYPASS_INTERFACE PROXY_INTERFACE DNS_HIJACK_PRE DNS_HIJACK_OUT APP_CHAIN MAC_CHAIN"
    fi

    local table="mangle"
    if [ "$mode" = "redirect" ]; then
        table="nat"
    fi

    # Create chains
    for c in $chains; do
        safe_chain_create "$family" "$table" "$c"
    done

    $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j "BYPASS_IP$suffix"
    $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j "PROXY_INTERFACE$suffix"
    $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j "MAC_CHAIN$suffix"
    $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j "DNS_HIJACK_PRE$suffix"

    $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j "BYPASS_IP$suffix"
    $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j "BYPASS_INTERFACE$suffix"
    $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j "APP_CHAIN$suffix"
    $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j "DNS_HIJACK_OUT$suffix"

    if check_kernel_feature "NETFILTER_XT_MATCH_ADDRTYPE"; then
        $cmd -t "$table" -A "BYPASS_IP$suffix" -m addrtype --dst-type LOCAL -p udp ! --dport 53 -j ACCEPT
        $cmd -t "$table" -A "BYPASS_IP$suffix" -m addrtype --dst-type LOCAL ! -p udp -j ACCEPT
        log Debug "Added local address type bypass"
    fi

    if check_kernel_feature "NETFILTER_XT_MATCH_CONNTRACK"; then
        $cmd -t "$table" -A "BYPASS_IP$suffix" -m conntrack --ctdir REPLY -j ACCEPT
        log Debug "Added reply connection direction bypass"
    fi

    # Add private IP ranges based on family
    if [ "$family" = "6" ]; then
        for subnet6 in ::/128 ::1/128 ::ffff:0:0/96 \
            100::/64 64:ff9b::/96 2001::/32 2001:10::/28 \
            2001:20::/28 2001:db8::/32 \
            2002::/16 fe80::/10 ff00::/8; do
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet6" -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet6" ! -p udp -j ACCEPT
        done
    else
        for subnet4 in 0.0.0.0/8 10.0.0.0/8 100.0.0.0/8 127.0.0.0/8 \
            169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 \
            192.168.0.0/16 198.51.100.0/24 203.0.113.0/24 \
            224.0.0.0/4 240.0.0.0/4 255.255.255.255/32; do
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet4" -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet4" ! -p udp -j ACCEPT
        done
    fi
    log Debug "Added bypass rules for private IP ranges"

    if [ "$BYPASS_CN_IP" -eq 1 ]; then
        ipset_name="cnip"
        if [ "$family" = "6" ]; then
            ipset_name="cnip6"
        fi
        if command -v ipset > /dev/null 2>&1 && ipset list "$ipset_name" > /dev/null 2>&1; then
            $cmd -t "$table" -A "BYPASS_IP$suffix" -m set --match-set "$ipset_name" dst -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -m set --match-set "$ipset_name" dst ! -p udp -j ACCEPT
            log Info "Added ipset-based CN IP bypass rule"
        else
            log Warn "ipset '$ipset_name' not available, skipping CN IP bypass"
        fi
    fi

    log Info "Configuring interface proxy rules"
    $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i lo -j RETURN
    if [ "$PROXY_MOBILE" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$MOBILE_INTERFACE" -j RETURN
        log Debug "Mobile interface $MOBILE_INTERFACE will be proxied"
    else
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$MOBILE_INTERFACE" -j ACCEPT
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$MOBILE_INTERFACE" -j ACCEPT
        log Debug "Mobile interface $MOBILE_INTERFACE will bypass proxy"
    fi
    if [ "$PROXY_WIFI" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" -j RETURN
        log Debug "WiFi interface $WIFI_INTERFACE will be proxied"
    else
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" -j ACCEPT
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$WIFI_INTERFACE" -j ACCEPT
        log Debug "WiFi interface $WIFI_INTERFACE will bypass proxy"
    fi
    if [ "$PROXY_HOTSPOT" -eq 1 ]; then
        if [ "$HOTSPOT_INTERFACE" = "$WIFI_INTERFACE" ]; then
            local subnet=""
            if [ "$family" = "6" ]; then
                subnet="fe80::/10"
            else
                subnet="192.168.43.0/24"
            fi
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" ! -s "$subnet" -j RETURN
            log Debug "Hotspot interface $WIFI_INTERFACE will be proxied"
        else
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$HOTSPOT_INTERFACE" -j RETURN
            log Debug "Hotspot interface $HOTSPOT_INTERFACE will be proxied"
        fi
    else
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$HOTSPOT_INTERFACE" -j ACCEPT
        log Debug "Hotspot interface $HOTSPOT_INTERFACE will bypass proxy"
    fi
    if [ "$PROXY_USB" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$USB_INTERFACE" -j RETURN
        log Debug "USB interface $USB_INTERFACE will be proxied"
    else
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$USB_INTERFACE" -j ACCEPT
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$USB_INTERFACE" -j ACCEPT
        log Debug "USB interface $USB_INTERFACE will bypass proxy"
    fi
    $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -j ACCEPT
    log Info "Interface proxy rules configuration completed"

    if [ "$MAC_FILTER_ENABLE" -eq 1 ] && [ "$PROXY_HOTSPOT" -eq 1 ] && [ -n "$HOTSPOT_INTERFACE" ]; then
        if check_kernel_feature "NETFILTER_XT_MATCH_MAC"; then
            log Info "Setting up MAC address filter rules for interface $HOTSPOT_INTERFACE"
            case "$MAC_PROXY_MODE" in
                blacklist)
                    if [ -n "$BYPASS_MACS_LIST" ]; then
                        for mac in $BYPASS_MACS_LIST; do
                            if [ -n "$mac" ]; then
                                $cmd -t "$table" -A "MAC_CHAIN$suffix" -m mac --mac-source "$mac" -i "$HOTSPOT_INTERFACE" -j ACCEPT
                                log Debug "Added MAC bypass rule for $mac"
                            fi
                        done
                    else
                        log Warn "MAC blacklist mode enabled but no bypass MACs configured"
                    fi
                    $cmd -t "$table" -A "MAC_CHAIN$suffix" -i "$HOTSPOT_INTERFACE" -j RETURN
                    ;;
                whitelist)
                    if [ -n "$PROXY_MACS_LIST" ]; then
                        for mac in $PROXY_MACS_LIST; do
                            if [ -n "$mac" ]; then
                                $cmd -t "$table" -A "MAC_CHAIN$suffix" -m mac --mac-source "$mac" -i "$HOTSPOT_INTERFACE" -j RETURN
                                log Debug "Added MAC proxy rule for $mac"
                            fi
                        done
                    else
                        log Warn "MAC whitelist mode enabled but no proxy MACs configured"
                    fi
                    $cmd -t "$table" -A "MAC_CHAIN$suffix" -i "$HOTSPOT_INTERFACE" -j ACCEPT
                    ;;
            esac
        else
            log Warn "MAC filtering requires NETFILTER_XT_MATCH_MAC kernel feature which is not available"
        fi
    fi

    if check_kernel_feature "NETFILTER_XT_MATCH_OWNER"; then
        $cmd -t "$table" -A "APP_CHAIN$suffix" -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
        log Debug "Added bypass for core user $CORE_USER:$CORE_GROUP"
    else
        log Warn "Kernel lacks OWNER match support."
    fi
    
    if check_kernel_feature "NETFILTER_XT_MATCH_MARK" && [ -n "$ROUTING_MARK" ]; then
        $cmd -t "$table" -A "APP_CHAIN$suffix" -m mark --mark "$ROUTING_MARK" -j ACCEPT
        log Debug "Added bypass for marked traffic with core mark $ROUTING_MARK"
    fi
    
    if ! check_kernel_feature "NETFILTER_XT_MATCH_OWNER" && { ! check_kernel_feature "NETFILTER_XT_MATCH_MARK" || [ -z "$ROUTING_MARK" ]; }; then
         log Warn "CRITICAL: No bypass mechanism (Owner/Mark) available! Infinite loop risk."
    fi

    if [ "$APP_PROXY_ENABLE" -eq 1 ]; then
        if check_kernel_feature "NETFILTER_XT_MATCH_OWNER"; then
            log Info "Setting up application filter rules in $APP_PROXY_MODE mode"
            case "$APP_PROXY_MODE" in
                blacklist)
                    if [ -n "$BYPASS_APPS_LIST" ]; then
                        uids=$(find_packages_uid "$BYPASS_APPS_LIST" || true)
                        for uid in $uids; do
                            if [ -n "$uid" ]; then
                                $cmd -t "$table" -A "APP_CHAIN$suffix" -m owner --uid-owner "$uid" -j ACCEPT
                                log Debug "Added bypass for UID $uid"
                            fi
                        done
                    else
                        log Warn "App blacklist mode enabled but no bypass apps configured"
                    fi
                    $cmd -t "$table" -A "APP_CHAIN$suffix" -j RETURN
                    ;;
                whitelist)
                    if [ -n "$PROXY_APPS_LIST" ]; then
                        uids=$(find_packages_uid "$PROXY_APPS_LIST" || true)
                        for uid in $uids; do
                            if [ -n "$uid" ]; then
                                $cmd -t "$table" -A "APP_CHAIN$suffix" -m owner --uid-owner "$uid" -j RETURN
                                log Debug "Added proxy for UID $uid"
                            fi
                        done
                    else
                        log Warn "App whitelist mode enabled but no proxy apps configured"
                    fi
                    $cmd -t "$table" -A "APP_CHAIN$suffix" -j ACCEPT
                    ;;
            esac
        else
            log Warn "Application filtering requires NETFILTER_XT_MATCH_OWNER kernel feature which is not available"
        fi
    fi

    if [ "$DNS_HIJACK_ENABLE" -ne 0 ]; then
        if [ "$mode" = "redirect" ]; then
            setup_dns_hijack "$family" "redirect"
        else
            if [ "$DNS_HIJACK_ENABLE" -eq 2 ]; then
                setup_dns_hijack "$family" "redirect2"
            else
                setup_dns_hijack "$family" "tproxy"
            fi
        fi
    fi

    if [ "$mode" = "tproxy" ]; then
        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p tcp -j TPROXY --on-port "$PROXY_TCP_PORT" --tproxy-mark "$mark"
        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p udp -j TPROXY --on-port "$PROXY_UDP_PORT" --tproxy-mark "$mark"
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j MARK --set-mark "$mark"
        log Info "TPROXY mode rules added"
    else
        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j REDIRECT --to-ports "$PROXY_TCP_PORT"
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j REDIRECT --to-ports "$PROXY_TCP_PORT"
        log Info "REDIRECT mode rules added"
    fi

    # Add rules to main chains
    if [ "$PROXY_UDP" -eq 1 ] || [ "$mode" = "redirect" ]; then
        $cmd -t "$table" -I PREROUTING -p udp -j "PROXY_PREROUTING$suffix"
        $cmd -t "$table" -I OUTPUT -p udp -j "PROXY_OUTPUT$suffix"
        log Info "Added UDP rules to PREROUTING and OUTPUT chains"
    fi
    if [ "$PROXY_TCP" -eq 1 ]; then
        $cmd -t "$table" -I PREROUTING -p tcp -j "PROXY_PREROUTING$suffix"
        $cmd -t "$table" -I OUTPUT -p tcp -j "PROXY_OUTPUT$suffix"
        log Info "Added TCP rules to PREROUTING and OUTPUT chains"
    fi

    log Info "$mode_name chains for IPv${family} setup completed"
}

setup_dns_hijack() {
    local family="$1"
    local mode="$2"
    local suffix=""
    local mark="$MARK_VALUE"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        mark="$MARK_VALUE6"
        cmd="ip6tables"
    fi

    case "$mode" in
        tproxy)
            # Handle DNS from interfaces in PREROUTING chain (DNS_HIJACK_PRE)
            $cmd -t mangle -A "DNS_HIJACK_PRE$suffix" -j RETURN
            # Handle local DNS hijacking in OUTPUT chain (DNS_HIJACK_OUT)
            $cmd -t mangle -A "DNS_HIJACK_OUT$suffix" -j RETURN

            log Info "DNS hijack enabled using TPROXY mode"
            ;;
        redirect)
            # Handle DNS using REDIRECT method
            $cmd -t nat -A "DNS_HIJACK_PRE$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "DNS_HIJACK_PRE$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "DNS_HIJACK_OUT$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "DNS_HIJACK_OUT$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"

            log Info "DNS hijack enabled using REDIRECT mode to port $DNS_PORT"
            ;;
        redirect2)
            # Handle DNS using REDIRECT method
            if [ "$family" = "6" ] && {
                ! check_kernel_feature "IP6_NF_NAT" || ! check_kernel_feature "IP6_NF_TARGET_REDIRECT"
            }; then
                log Warn "IPv6: Kernel does not support IPv6 NAT or REDIRECT, skipping IPv6 DNS hijack"
                return 0
            fi
            safe_chain_create "$family" "nat" "NAT_DNS_HIJACK$suffix"
            $cmd -t nat -A "NAT_DNS_HIJACK$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "NAT_DNS_HIJACK$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"

            [ "$PROXY_MOBILE" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$MOBILE_INTERFACE" -j "NAT_DNS_HIJACK$suffix"
            [ "$PROXY_WIFI" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$WIFI_INTERFACE" -j "NAT_DNS_HIJACK$suffix"
            [ "$PROXY_USB" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$USB_INTERFACE" -j "NAT_DNS_HIJACK$suffix"

            $cmd -t nat -A OUTPUT -p udp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
            $cmd -t nat -A OUTPUT -p tcp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
            $cmd -t nat -A OUTPUT -j "NAT_DNS_HIJACK$suffix"

            log Info "DNS hijack enabled using REDIRECT mode to port $DNS_PORT"
            ;;
    esac
}

setup_tproxy_chain4() {
    setup_proxy_chain 4 "tproxy"
}

setup_redirect_chain4() {
    log Warn "REDIRECT mode only supports TCP"
    setup_proxy_chain 4 "redirect"
}

setup_tproxy_chain6() {
    setup_proxy_chain 6 "tproxy"
}

setup_redirect_chain6() {
    if ! check_kernel_feature "IP6_NF_NAT" || ! check_kernel_feature "IP6_NF_TARGET_REDIRECT"; then
        log Warn "IPv6: Kernel does not support IPv6 NAT or REDIRECT, skipping IPv6 proxy setup"
        return 0
    fi
    log Warn "REDIRECT mode only supports TCP"
    setup_proxy_chain 6 "redirect"
}

setup_routing4() {
    log Info "Setting up routing rules for IPv4"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip rule add fwmark $MARK_VALUE lookup $TABLE_ID"
        log Debug "[DRY-RUN] ip route add local 0.0.0.0/0 dev lo table $TABLE_ID"
        log Debug "[DRY-RUN] echo 1 > /proc/sys/net/ipv4/ip_forward"
    else
        ip_rule del fwmark "$MARK_VALUE" lookup "$TABLE_ID" 2> /dev/null || true
        ip_route del local 0.0.0.0/0 dev lo table "$TABLE_ID" 2> /dev/null || true

        if ! ip_rule add fwmark "$MARK_VALUE" table "$TABLE_ID" pref "$TABLE_ID"; then
            log Error "Failed to add IPv4 routing rule"
            return 1
        fi

        if ! ip_route add local 0.0.0.0/0 dev lo table "$TABLE_ID"; then
            log Error "Failed to add IPv4 route"
            ip_rule del fwmark "$MARK_VALUE" table "$TABLE_ID" pref "$TABLE_ID" 2> /dev/null || true
            return 1
        fi

        echo 1 > /proc/sys/net/ipv4/ip_forward
    fi

    log Info "IPv4 routing setup completed"
}

setup_routing6() {
    log Info "Setting up routing rules for IPv6"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip -6 rule add fwmark $MARK_VALUE6 lookup $TABLE_ID"
        log Debug "[DRY-RUN] ip -6 route add local ::/0 dev lo table $TABLE_ID"
        log Debug "[DRY-RUN] echo 1 > /proc/sys/net/ipv6/conf/all/forwarding"
    else
        ip6_rule del fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID" 2> /dev/null || true
        ip6_route del local ::/0 dev lo table "$TABLE_ID" 2> /dev/null || true

        if ! ip6_rule add fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID"; then
            log Error "Failed to add IPv6 routing rule"
            return 1
        fi

        if ! ip6_route add local ::/0 dev lo table "$TABLE_ID"; then
            log Error "Failed to add IPv6 route"
            ip6_rule del fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID" 2> /dev/null || true
            return 1
        fi

        echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
    fi

    log Info "IPv6 routing setup completed"
}

# Unified cleanup function for both IPv4 and IPv6 with mode selection
cleanup_chain() {
    local family="$1"
    local mode="$2"
    local suffix=""
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        cmd="ip6tables"
    fi

    # Set mode name for logging
    local mode_name="$mode"
    if [ "$mode" = "tproxy" ]; then
        mode_name="TPROXY"
    else
        mode_name="REDIRECT"
    fi

    log Info "Cleaning up $mode_name chains for IPv${family}"

    local table="mangle"
    if [ "$mode" = "redirect" ]; then
        table="nat"
    fi

    # Remove rules from main chains
    $cmd -t "$table" -D "PROXY_PREROUTING$suffix" -j "BYPASS_IP$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_PREROUTING$suffix" -j "PROXY_INTERFACE$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_PREROUTING$suffix" -j "MAC_CHAIN$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_PREROUTING$suffix" -j "DNS_HIJACK_PRE$suffix" 2> /dev/null || true

    $cmd -t "$table" -D "PROXY_OUTPUT$suffix" -j "BYPASS_IP$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_OUTPUT$suffix" -j "BYPASS_INTERFACE$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_OUTPUT$suffix" -j "APP_CHAIN$suffix" 2> /dev/null || true
    $cmd -t "$table" -D "PROXY_OUTPUT$suffix" -j "DNS_HIJACK_OUT$suffix" 2> /dev/null || true

    if [ "$PROXY_TCP" -eq 1 ]; then
        $cmd -t "$table" -D PREROUTING -p tcp -j "PROXY_PREROUTING$suffix" 2> /dev/null || true
        $cmd -t "$table" -D OUTPUT -p tcp -j "PROXY_OUTPUT$suffix" 2> /dev/null || true
    fi
    if [ "$PROXY_UDP" -eq 1 ]; then
        $cmd -t "$table" -D PREROUTING -p udp -j "PROXY_PREROUTING$suffix" 2> /dev/null || true
        $cmd -t "$table" -D OUTPUT -p udp -j "PROXY_OUTPUT$suffix" 2> /dev/null || true
    fi

    # Define chains based on family
    local chains=""
    if [ "$family" = "6" ]; then
        chains="PROXY_PREROUTING6 PROXY_OUTPUT6 BYPASS_IP6 BYPASS_INTERFACE6 PROXY_INTERFACE6 DNS_HIJACK_PRE6 DNS_HIJACK_OUT6 APP_CHAIN6 MAC_CHAIN6"
    else
        chains="PROXY_PREROUTING PROXY_OUTPUT BYPASS_IP BYPASS_INTERFACE PROXY_INTERFACE DNS_HIJACK_PRE DNS_HIJACK_OUT APP_CHAIN MAC_CHAIN"
    fi

    # Clean up chains
    for c in $chains; do
        $cmd -t "$table" -F "$c" 2> /dev/null || true
        $cmd -t "$table" -X "$c" 2> /dev/null || true
    done

    # Remove DNS rules if applicable
    if [ "$mode" = "tproxy" ] && [ "$DNS_HIJACK_ENABLE" -eq 2 ]; then
        $cmd -t nat -D PREROUTING -i "$MOBILE_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -D PREROUTING -i "$WIFI_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -D PREROUTING -i "$USB_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -D OUTPUT -p udp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT 2> /dev/null || true
        $cmd -t nat -D OUTPUT -p tcp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT 2> /dev/null || true
        $cmd -t nat -D OUTPUT -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -F "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -X "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
    fi

    log Info "$mode_name chains for IPv${family} cleanup completed"
}

cleanup_tproxy_chain4() {
    cleanup_chain 4 "tproxy"
}

cleanup_tproxy_chain6() {
    cleanup_chain 6 "tproxy"
}

cleanup_redirect_chain4() {
    cleanup_chain 4 "redirect"
}

cleanup_redirect_chain6() {
    if ! check_kernel_feature "IP6_NF_NAT" || ! check_kernel_feature "IP6_NF_TARGET_REDIRECT"; then
        log Warn "IPv6: Kernel does not support IPv6 NAT or REDIRECT, skipping IPv6 cleanup"
        return 0
    fi
    cleanup_chain 6 "redirect"
}

cleanup_routing4() {
    log Info "Cleaning up IPv4 routing rules"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip rule del fwmark $MARK_VALUE table $TABLE_ID pref $TABLE_ID"
        log Debug "[DRY-RUN] ip route del local 0.0.0.0/0 dev lo table $TABLE_ID"
        log Debug "[DRY-RUN] echo 0 > /proc/sys/net/ipv4/ip_forward"
    else
        ip_rule del fwmark "$MARK_VALUE" table "$TABLE_ID" pref "$TABLE_ID" 2> /dev/null || true
        ip_route del local 0.0.0.0/0 dev lo table "$TABLE_ID" 2> /dev/null || true
        echo 0 > /proc/sys/net/ipv4/ip_forward 2> /dev/null || true
    fi

    log Info "IPv4 routing cleanup completed"
}

cleanup_routing6() {
    log Info "Cleaning up IPv6 routing rules"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ip -6 rule del fwmark $MARK_VALUE6 table $TABLE_ID pref $TABLE_ID"
        log Debug "[DRY-RUN] ip -6 route del local ::/0 dev lo table $TABLE_ID"
        log Debug "[DRY-RUN] echo 0 > /proc/sys/net/ipv6/conf/all/forwarding"
    else
        ip6_rule del fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID" 2> /dev/null || true
        ip6_route del local ::/0 dev lo table "$TABLE_ID" 2> /dev/null || true
        echo 0 > /proc/sys/net/ipv6/conf/all/forwarding 2> /dev/null || true
    fi

    log Info "IPv6 routing cleanup completed"
}

cleanup_ipset() {
    if [ "$BYPASS_CN_IP" -eq 0 ]; then
        log Debug "CN IP bypass is disabled, skipping ipset cleanup"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[DRY-RUN] ipset destroy cnip"
        log Debug "[DRY-RUN] ipset destroy cnip6"
    else
        ipset destroy cnip 2> /dev/null || true
        ipset destroy cnip6 2> /dev/null || true
        log Info "ipset 'cnip' and 'cnip6' destroyed"
    fi
}

detect_proxy_mode() {
    USE_TPROXY=0
    case "$PROXY_MODE" in
        0)
            if check_tproxy_support; then
                USE_TPROXY=1
                log Info "Kernel supports TPROXY, using TPROXY mode (auto)"
            else
                log Warn "Kernel does not support TPROXY, falling back to REDIRECT mode (auto)"
            fi
            ;;
        1)
            if check_tproxy_support; then
                USE_TPROXY=1
                log Info "Using TPROXY mode (forced by configuration)"
            else
                log Error "TPROXY mode forced but kernel does not support TPROXY"
                exit 1
            fi
            ;;
        2)
            log Info "Using REDIRECT mode (forced by configuration)"
            ;;
    esac
}

start_proxy() {
    log Info "Starting proxy setup..."
    if [ "$BYPASS_CN_IP" -eq 1 ]; then
        if ! check_kernel_feature "IP_SET" || ! check_kernel_feature "NETFILTER_XT_SET"; then
            log Error "Kernel does not support ipset (CONFIG_IP_SET, CONFIG_NETFILTER_XT_SET). Cannot bypass CN IPs"
            BYPASS_CN_IP=0
        else
            download_cn_ip_list || log Warn "Failed to download CN IP list, continuing without it"
            if ! setup_cn_ipset; then
                log Error "Failed to setup ipset, CN bypass disabled"
                BYPASS_CN_IP=0
            fi
        fi
    fi

    if [ "$USE_TPROXY" -eq 1 ]; then
        setup_tproxy_chain4
        setup_routing4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            setup_tproxy_chain6
            setup_routing6
        fi
    else
        setup_redirect_chain4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            setup_redirect_chain6
        fi
    fi
    log Info "Proxy setup completed"
}

stop_proxy() {
    log Info "Stopping proxy..."
    if [ "$USE_TPROXY" -eq 1 ]; then
        log Info "Cleaning up TPROXY chains"
        cleanup_tproxy_chain4
        cleanup_routing4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            cleanup_tproxy_chain6
            cleanup_routing6
        fi
    else
        log Info "Cleaning up REDIRECT chains"
        cleanup_redirect_chain4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            cleanup_redirect_chain6
        fi
    fi
    cleanup_ipset
    log Info "Proxy stopped"
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") {start|stop|restart} [--dry-run]

Options:
  --dry-run    Run without making actual changes
  -h, --help   Show this help message
EOF
}

parse_args() {
    MAIN_CMD=""

    while [ $# -gt 0 ]; do
        case "$1" in
            start | stop | restart)
                if [ -n "$MAIN_CMD" ]; then
                    log Error "Multiple commands specified."
                    exit 1
                fi
                MAIN_CMD="$1"
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log Error "Invalid argument: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done

    if [ -z "$MAIN_CMD" ]; then
        log Error "No command specified"
        show_usage
        exit 1
    fi
}

main() {
    load_config
    if ! validate_config; then
        log Error "Configuration validation failed"
        exit 1
    fi

    check_root
    check_dependencies

    detect_proxy_mode

    case "$MAIN_CMD" in
        start)
            start_proxy
            ;;
        stop)
            stop_proxy
            ;;
        restart)
            log Info "Restarting proxy..."
            stop_proxy
            sleep 2
            start_proxy
            log Info "Proxy restarted"
            ;;
        *)
            log Error "Invalid command: $MAIN_CMD"
            show_usage
            exit 1
            ;;
    esac
}

parse_args "$@"

main
