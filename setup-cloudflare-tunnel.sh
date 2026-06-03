#!/bin/bash
#
# setup-cloudflare-tunnel.sh
#
# Helper script to set up Cloudflare Tunnel for nodecast-tv
# Run this on your Oracle Cloud (or other) VM after the app is running via docker compose.
#
# This gives you free HTTPS, a nice URL (trycloudflare.com or your own domain),
# and strong security (no need to open port 3000 on the VM).
#
# Prerequisites:
# - nodecast-tv running in docker compose (http://localhost:3000 inside VM)
# - You have a Cloudflare account (free is fine)
#
# Usage:
#   chmod +x setup-cloudflare-tunnel.sh
#   ./setup-cloudflare-tunnel.sh
#
# For a quick temporary URL (no login needed for basic test):
#   cloudflared tunnel --url http://localhost:3000
#

set -e

echo "=== nodecast-tv Cloudflare Tunnel Setup ==="
echo "This will install cloudflared (if needed) and guide you through creating a tunnel."
echo ""

# Detect architecture (Oracle Ampere is usually aarch64/arm64)
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
  echo "Detected arm64/aarch64 (common for Oracle Always Free Ampere)"
else
  DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
  echo "Detected amd64"
fi

if ! command -v cloudflared &> /dev/null; then
  echo "Installing cloudflared..."
  curl -L "$DEB_URL" -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb || sudo apt install -f -y
  echo "cloudflared installed."
else
  echo "cloudflared is already installed."
fi

echo ""
echo "=== Quick Test (temporary URL, no account needed for basic use) ==="
echo "You can run this in another terminal for an instant public URL:"
echo "  cloudflared tunnel --url http://localhost:3000"
echo "It will print a https://xxxxx.trycloudflare.com link."
echo "Press Ctrl+C when done testing."
echo ""
read -p "Press Enter to continue with the full named tunnel setup (recommended for permanent use)..."

echo ""
echo "=== Full Permanent Tunnel Setup ==="
echo "1. You will be asked to log in to Cloudflare (opens browser or gives URL)."
echo "2. Choose a tunnel name (e.g. nodecast-tv)."
echo "3. Optionally route a custom domain/subdomain."
echo "4. We will show how to run it persistently."
echo ""

cloudflared tunnel login

echo ""
read -p "Enter a name for this tunnel (default: nodecast-tv): " TUNNEL_NAME
TUNNEL_NAME=${TUNNEL_NAME:-nodecast-tv}

echo "Creating tunnel '$TUNNEL_NAME'..."
cloudflared tunnel create "$TUNNEL_NAME" || true

echo ""
echo "To run the tunnel pointing to your local app:"
echo "  cloudflared tunnel run --url http://localhost:3000 $TUNNEL_NAME"
echo ""
echo "For a custom domain (you must own the domain and have it in Cloudflare):"
echo "  cloudflared tunnel route dns $TUNNEL_NAME tv.yourdomain.com"
echo "  Then run the tunnel as above."
echo ""

echo "=== Running as a Service (recommended so it survives reboots) ==="
echo "We can create a systemd service for the tunnel."
read -p "Create systemd service for the tunnel now? (y/n) " CREATE_SERVICE

if [ "$CREATE_SERVICE" = "y" ] || [ "$CREATE_SERVICE" = "Y" ]; then
  SERVICE_NAME="cloudflared-$TUNNEL_NAME"
  echo "Creating systemd service $SERVICE_NAME..."

  sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for nodecast-tv
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=/usr/bin/cloudflared tunnel run --url http://localhost:3000 $TUNNEL_NAME
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now "$SERVICE_NAME"

  echo "Service created and started."
  echo "Check status: sudo systemctl status $SERVICE_NAME"
  echo "Logs: journalctl -u $SERVICE_NAME -f"
else
  echo "Skipped service. You can run manually with:"
  echo "  cloudflared tunnel run --url http://localhost:3000 $TUNNEL_NAME"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Your app should now be accessible via the tunnel URL(s) printed above or in the service logs."
echo "2. Open the URL in your browser — you should see the nodecast-tv login/setup."
echo "3. IMPORTANT: In Settings → Transcoding, set:"
echo "   - Hardware Encoder: software"
echo "   - Max Resolution: 720p (or 480p)"
echo "   - Quality: low"
echo "   (Oracle free tier is CPU-only and shared.)"
echo "4. Create your admin account on first visit if prompted."
echo "5. (Optional but recommended) Tighten Oracle security list to only allow your IP for SSH (port 22). No need for port 3000 anymore thanks to the tunnel."
echo ""
echo "Done! Your nodecast-tv is now 'hosted to Cloudflare' via Tunnel."
echo "For updates: git pull on the VM, then docker compose up -d --build"
echo ""
echo "See full docs in DEPLOY.md for more details (Coolify, custom domains, etc.)."