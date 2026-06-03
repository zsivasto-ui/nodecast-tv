#!/bin/bash
#
# oracle-cloudflare-deploy.sh
#
# One-stop script to deploy nodecast-tv on an Oracle Cloud Always Free VM
# and expose it via Cloudflare Tunnel.
#
# Run this on a fresh Ubuntu 24.04 (arm64) Oracle VM after SSHing in.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/nodecast-tv/main/oracle-cloudflare-deploy.sh -o deploy.sh
#   chmod +x deploy.sh
#   ./deploy.sh https://github.com/YOUR_USERNAME/nodecast-tv.git [optional-tunnel-name]
#
# This script will:
# 1. Update system and install Docker
# 2. Clone your repo
# 3. Build and start the app with docker compose
# 4. Run the Cloudflare Tunnel setup script (interactive)
#
# After it finishes, follow the on-screen instructions for the final app config.
#

set -e

GITHUB_REPO=${1:-"https://github.com/technomancer702/nodecast-tv.git"}
TUNNEL_NAME=${2:-"nodecast-tv"}

echo "=== nodecast-tv Oracle + Cloudflare Deployment ==="
echo "Repo: $GITHUB_REPO"
echo "Tunnel name: $TUNNEL_NAME"
echo ""

# 1. System update and Docker install
echo "[1/4] Updating system and installing Docker..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ca-certificates gnupg lsb-release

if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  sudo usermod -aG docker $USER
  echo "Docker installed. You may need to log out and back in for group changes, but we'll use sudo for now."
fi

# Ensure docker compose is available (newer Docker has it built-in)
docker compose version || (sudo apt install -y docker-compose-plugin)

# 2. Clone the repo
echo "[2/4] Cloning repo..."
if [ -d "nodecast-tv" ]; then
  echo "Directory nodecast-tv already exists, pulling latest..."
  cd nodecast-tv
  git pull || true
else
  git clone "$GITHUB_REPO" nodecast-tv
  cd nodecast-tv
fi

# 3. Deploy the app
echo "[3/4] Building and starting nodecast-tv with docker compose..."
# The compose file now defaults to local build which works great on arm64
docker compose up -d --build

echo "Waiting for container to be healthy (basic check)..."
sleep 10
docker compose ps

echo ""
echo "App should be running at http://localhost:3000 inside the VM."
echo "You can test with: curl http://localhost:3000/api/version"
echo ""

# 4. Cloudflare Tunnel
echo "[4/4] Setting up Cloudflare Tunnel..."
if [ -f "./setup-cloudflare-tunnel.sh" ]; then
  chmod +x ./setup-cloudflare-tunnel.sh
  ./setup-cloudflare-tunnel.sh
else
  echo "Tunnel script not found in repo. Falling back to manual instructions."
  echo "Please run the commands from DEPLOY.md or the setup script manually."
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps (do these after the tunnel gives you a URL):"
echo "1. Open the Cloudflare Tunnel URL in your browser."
echo "2. Create your admin account (first visit on a fresh deploy)."
echo "3. Go to Settings > Transcoding and set:"
echo "   - Hardware Encoder: software"
echo "   - Max Resolution: 720p or 480p"
echo "   - Quality: low"
echo "4. Add your IPTV sources in Content Sources."
echo ""
echo "Security: After tunnel is working, go to Oracle Console and restrict"
echo "the Security List to only allow your IP on port 22 (SSH). Port 3000 can be removed."
echo ""
echo "To update later:"
echo "  cd nodecast-tv && git pull && docker compose up -d --build"
echo ""
echo "Logs: docker compose logs -f"
echo ""
echo "Enjoy your nodecast-tv hosted behind Cloudflare!"