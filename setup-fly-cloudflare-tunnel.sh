#!/bin/bash
#
# setup-fly-cloudflare-tunnel.sh
#
# Mac-friendly helper for putting your Fly.io nodecast-tv app behind Cloudflare.
# (Works on macOS + Linux for quick tests.)
#
# Why this exists:
# - Your app is already publicly reachable on Fly (https://nodecast-tv-zsivasto.fly.dev).
# - We can instantly give it a Cloudflare trycloudflare.com URL (or a named stable tunnel).
# - No need for local `fly proxy` — we tunnel directly to the public Fly hostname.
# - Alternative (recommended for production): just use Cloudflare DNS CNAME + proxy (no tunnel process at all).
#
# Usage:
#   cd nodecast-tv
#   chmod +x setup-fly-cloudflare-tunnel.sh
#   ./setup-fly-cloudflare-tunnel.sh
#
# Requirements: cloudflared installed (brew install cloudflare/cloudflare/cloudflared on Mac)
#

set -e

APP_HOST="nodecast-tv-zsivasto.fly.dev"
APP_URL="https://${APP_HOST}"
TUNNEL_NAME_DEFAULT="nodecast-tv"

echo "=== nodecast-tv Fly.io + Cloudflare Tunnel Setup ==="
echo "Target app: ${APP_URL}"
echo ""

# --- Detect / ensure cloudflared ---
if ! command -v cloudflared &> /dev/null; then
  echo "cloudflared not found."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "On macOS, install with:"
    echo "  brew install cloudflare/cloudflare/cloudflared"
    echo "Or: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  else
    echo "Install instructions: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  fi
  exit 1
fi

cloudflared --version
echo ""

echo "Choose an option:"
echo "  1) Quick ephemeral Cloudflare URL (no login, changes every run)  [RECOMMENDED TO TEST NOW]"
echo "  2) Named tunnel (stable ID, requires Cloudflare login once)"
echo "  3) Show commands only (no changes)"
echo "  4) Help with the *simpler* Cloudflare DNS CNAME method (no tunnel process needed)"
echo "  5) Exit"
echo ""
read -p "Enter choice [1-5]: " CHOICE

case "$CHOICE" in
  1)
    echo ""
    echo "=== Quick Ephemeral Tunnel ==="
    echo "This will give you a https://xxxxx.trycloudflare.com URL that proxies to your Fly app."
    echo "Keep this process running in a terminal tab/window."
    echo "Press Ctrl+C to stop the tunnel."
    echo ""
    echo "Running: cloudflared tunnel --url ${APP_URL}"
    echo ""
    cloudflared tunnel --url "${APP_URL}"
    ;;

  2)
    echo ""
    echo "=== Named Tunnel Setup (persistent ID) ==="
    echo "You will need to complete a one-time browser login to Cloudflare."
    echo ""

    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
      echo "No cert.pem found. Running 'cloudflared tunnel login' now..."
      echo "A browser (or URL) will appear — log in and authorize."
      echo ""
      cloudflared tunnel login
    else
      echo "Existing Cloudflare cert found at ~/.cloudflared/cert.pem"
    fi

    echo ""
    read -p "Tunnel name (default: ${TUNNEL_NAME_DEFAULT}): " TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-$TUNNEL_NAME_DEFAULT}

    echo "Creating (or ensuring) tunnel '$TUNNEL_NAME'..."
    cloudflared tunnel create "$TUNNEL_NAME" || true

    echo ""
    echo "To run the named tunnel (proxies to your Fly app):"
    echo "  cloudflared tunnel run --url ${APP_URL} ${TUNNEL_NAME}"
    echo ""

    read -p "Start the tunnel now (keep running)? (y/n) " START_NOW
    if [[ "$START_NOW" =~ ^[Yy] ]]; then
      echo "Starting named tunnel... (Ctrl+C to stop)"
      cloudflared tunnel run --url "${APP_URL}" "${TUNNEL_NAME}"
    else
      echo "You can start it anytime with the command above."
    fi

    echo ""
    echo "For a custom domain later (after you add the domain to Cloudflare):"
    echo "  cloudflared tunnel route dns ${TUNNEL_NAME} live.yourdomain.com"
    echo "Then use a config.yml for hostname-based routing (see docs)."
    ;;

  3)
    echo ""
    echo "=== Commands only (copy-paste) ==="
    echo ""
    echo "# Quick test (no account):"
    echo "cloudflared tunnel --url ${APP_URL}"
    echo ""
    echo "# Named (after you have logged in once):"
    echo "cloudflared tunnel login"
    echo "cloudflared tunnel create nodecast-tv"
    echo "cloudflared tunnel run --url ${APP_URL} nodecast-tv"
    echo ""
    ;;

  4)
    echo ""
    echo "=== Recommended for Fly: Cloudflare DNS CNAME (no tunnel process) ==="
    echo ""
    echo "This is usually the cleanest for a Fly.io app:"
    echo "1. Decide on a domain/subdomain you control in Cloudflare (e.g. tv.yourdomain.com)."
    echo "2. In Fly dashboard or CLI, add the cert:"
    echo "   fly certs create tv.yourdomain.com -a nodecast-tv-zsivasto"
    echo "   (or do it in the Fly web UI under your app → Certificates)."
    echo ""
    echo "3. In Cloudflare DNS for your domain:"
    echo "   Type: CNAME"
    echo "   Name: tv   (or whatever subdomain)"
    echo "   Target: nodecast-tv-zsivasto.fly.dev"
    echo "   Proxy status: Proxied (orange cloud)  ← important"
    echo ""
    echo "4. In Cloudflare → SSL/TLS → Overview for the domain: set to 'Full' or 'Full (strict)'."
    echo ""
    echo "5. (Optional but nice) In Cloudflare → Rules → Page Rules or Transform Rules if you want to force /#live etc."
    echo ""
    echo "Benefits:"
    echo "- Your own nice domain with Cloudflare security, DDoS protection, caching options."
    echo "- No extra process to keep alive on your Mac."
    echo "- Fly still handles the origin traffic."
    echo ""
    echo "After DNS propagates (usually fast with orange cloud), visit https://tv.yourdomain.com"
    echo ""
    echo "If you want the root or specific path, you can also set up Cloudflare Workers or just use the subdomain."
    ;;

  5)
    echo "Exiting."
    exit 0
    ;;
  *)
    echo "Invalid choice."
    exit 1
    ;;
esac

echo ""
echo "=== After your Cloudflare URL/domain works ==="
echo "1. Open it in the browser."
echo "2. Create your first admin user (if it's a fresh data dir)."
echo "3. IMPORTANT for Fly free tier:"
echo "   Settings → Transcoding"
echo "     Hardware Encoder: software"
echo "     Max Resolution: 720p (or 480p)"
echo "     Quality: low"
echo "4. Add your content sources (Xtream or M3U)."
echo "5. Test Live TV (#live section)."
echo ""
echo "Useful Fly commands:"
echo "  fly logs -a nodecast-tv-zsivasto"
echo "  fly status -a nodecast-tv-zsivasto"
echo "  fly ssh console -a nodecast-tv-zsivasto"
echo ""
echo "To make a Mac tunnel auto-start on login (launchd example):"
echo "  See the comments at the bottom of this script, or ask me to generate a plist."
echo ""
echo "Done! Your nodecast-tv is now reachable via Cloudflare."
echo "Update the app with: git pull && fly deploy (from the nodecast-tv dir)"
echo ""

# --- Optional launchd notes (printed for Mac users) ---
cat << 'LAUNCHD_NOTES'

--- Making the tunnel start automatically on macOS (optional) ---
If you want the named tunnel to run whenever you are logged in:

1. Create ~/Library/LaunchAgents/com.nodecast.cloudflared.plist

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nodecast.cloudflared</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/cloudflared</string>
        <string>tunnel</string>
        <string>run</string>
        <string>--url</string>
        <string>https://nodecast-tv-zsivasto.fly.dev</string>
        <string>nodecast-tv</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/cloudflared-nodecast.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/cloudflared-nodecast.log</string>
</dict>
</plist>

2. Then:
   launchctl load ~/Library/LaunchAgents/com.nodecast.cloudflared.plist
   launchctl start com.nodecast.cloudflared

3. Check logs: tail -f /tmp/cloudflared-nodecast.log

Note: This only works while your Mac is awake and you are logged in.
For a truly always-on setup, consider:
- The CNAME method above (best), or
- Running cloudflared inside the Fly machine (we can bake it into the Dockerfile + entrypoint script).

LAUNCHD_NOTES

exit 0
