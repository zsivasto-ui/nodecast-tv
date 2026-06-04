# nodecast-tv Deployment Session Resume (2026-06-03)

## Current State
- Code pushed to your fork: https://github.com/zsivasto-ui/nodecast-tv
- Latest commit on main includes:
  - Custom deploy scripts (oracle-cloudflare-deploy.sh, setup-cloudflare-tunnel.sh)
  - CLOUDFLARE_DEPLOY_STEPS.md with ready commands
  - fly.toml configured for Fly.io (app: nodecast-tv-zsivasto, region: iad, volume mount for /app/data)
  - SSH key generated locally: ~/.ssh/oracle-nodecast (public key in previous notes)
- You were in the middle of `fly launch` (correct app name from toml).
- fly proxy and tunnel setup script were being tested (local Mac proxy + cloudflared for quick Cloudflare URL while Fly app runs).

## What We Accomplished
- Pushed all custom work (auth improvements, About tab, free-tier defaults, deploy scripts).
- Prepared Oracle path (but hit capacity/region limits in Chicago; Ashburn subscription blocked by tenancy limits).
- Switched to Fly.io as easier free alternative with pre-made fly.toml + Dockerfile.
- Generated Oracle SSH key (can reuse for new tenancy if needed).
- fly launch reached the final "tweak settings" prompt with correct config.

## To Resume (Recommended: Finish Fly.io + Cloudflare)
1. Make sure you're in the project dir:
   cd /Users/steve/nodecast-tv

2. Resume/complete Fly launch (answer N to tweaks if the summary looks good):
   fly launch

3. Create the persistent volume (critical for /app/data):
   fly volumes create nodecast_data --size 1 --region iad

4. Deploy (attaches volume):
   fly deploy

5. App should be live at https://nodecast-tv-zsivasto.fly.dev (or your chosen name).

6. Quick test access via local proxy + Cloudflare (while testing):
   - Terminal 1 (keep running): fly proxy 3000:3000 -a nodecast-tv-zsivasto
   - Terminal 2: cloudflared tunnel --url http://localhost:3000
   - This gives a temp Cloudflare URL (trycloudflare.com) that reaches your Fly app.

7. Permanent Cloudflare Tunnel setup (run on your Mac or move to server later):
   - Run the script locally first for testing (with proxy above):
     curl -fsSL https://raw.githubusercontent.com/zsivasto-ui/nodecast-tv/main/setup-cloudflare-tunnel.sh -o /tmp/setup.sh
     chmod +x /tmp/setup.sh
     /tmp/setup.sh
   - Follow prompts (login, tunnel name e.g. "nodecast-tv").
   - For server-side (better long-term): After app is on Fly, use `fly ssh console` and run the setup script inside the machine (or use machine exec + token for background tunnel).

8. After tunnel URL works:
   - Open the Cloudflare URL.
   - Create admin account.
   - Settings → Transcoding: software + 720p/low (free tier is limited).
   - Add your sources.
   - Security: In Fly dashboard or Cloudflare, lock down as needed.

## Oracle Path (if you want to try again later)
- Create new Oracle account (different email) and pick Ashburn as home region during signup (bypasses your current tenancy limits).
- Use the steps in CLOUDFLARE_DEPLOY_STEPS.md (or the one-command oracle-cloudflare-deploy.sh).
- SSH key is ready: ~/.ssh/oracle-nodecast
- Deploy script ready in repo.

## Useful Commands
- Check Fly app: fly status -a nodecast-tv-zsivasto
- View logs: fly logs -a nodecast-tv-zsivasto
- SSH to Fly machine: fly ssh console -a nodecast-tv-zsivasto
- Destroy old blank app if wanted: fly apps destroy steve-bitter-stream-5717 --yes
- Update code and redeploy: git pull && fly deploy (or git push to trigger if using GitHub deploy)

## Notes / Gotchas
- Free tier on Fly: small resources → use software transcoding + low res in app Settings.
- Volume is critical for persistence (/app/data).
- Tunnel script sets up cloudflared; run it where the app's localhost:3000 is reachable (Mac proxy for now, or inside Fly machine).
- Push any local changes: git add . && git commit -m "..." && git push myfork main
- All custom work (auth, UI, scripts) is in your fork.

## Progress 2026-06-04 - Cloudflare Setup Started
- App confirmed live: https://nodecast-tv-zsivasto.fly.dev (1 machine in iad, volume attached)
- Orphan volume cleaned up (only the attached one remains).
- cloudflared installed locally, version 2026.5.2
- Quick Cloudflare Tunnel test succeeded (using direct --url to Fly hostname, no local proxy needed):
  - Example URL generated: https://instruction-arbitration-cons-organizer.trycloudflare.com (was active while tunnel process ran)
  - Note: quick/anonymous tunnels are ephemeral; run the command below with process kept alive for a live CF URL.
- Login flow initiated for named tunnels (full setup / stable ID / future custom domain routing).
- fly proxy had connectivity issue in harness (not user env); direct --url to public Fly URL works great for CF fronting.
- No cert.pem yet in ~/.cloudflared (pending browser auth completion).
- Added Mac-friendly helper: setup-fly-cloudflare-tunnel.sh (interactive menu for quick/named/CNAME)
- Added launchd example: com.nodecast.cloudflared.plist.example (for auto-start on Mac login)

## How to Continue Cloudflare Setup Now (Run these in your terminal)
1. Best starting point — run the new interactive helper we just created:
   ```bash
   cd /Users/steve/nodecast-tv
   ./setup-fly-cloudflare-tunnel.sh
   ```
   It has a menu for:
   - Quick trycloudflare.com URL (option 1 — do this first, no login needed)
   - Named tunnel full setup (option 2)
   - The simpler Cloudflare DNS CNAME method (option 4 — often best for Fly)

2. If you prefer manual quick test right now (no login):
   ```bash
   cloudflared tunnel --url https://nodecast-tv-zsivasto.fly.dev
   ```
   Keep the process running. It will print a https://...trycloudflare.com link. Visit it + `#live`.

3. For named tunnel (stable):
   - First complete browser login: `cloudflared tunnel login` (it will give you a URL like the previous one)
   - Then: `cloudflared tunnel create nodecast-tv`
   - Run: `cloudflared tunnel run --url https://nodecast-tv-zsivasto.fly.dev nodecast-tv`

4. Auto-start on your Mac (launchd):
   - Copy the example: `cp com.nodecast.cloudflared.plist.example ~/Library/LaunchAgents/com.nodecast.cloudflared.plist`
   - Edit the plist if you used a different tunnel name.
   - `launchctl load ~/Library/LaunchAgents/com.nodecast.cloudflared.plist`
   - `launchctl start com.nodecast.cloudflared`
   - Logs: `tail -f /tmp/cloudflared-nodecast.log`

   (Note: only runs while your Mac is on and you're logged in. For 24/7 use the CNAME method or run cloudflared inside Fly.)

5. (Strongly recommended long-term for Fly apps) Use Cloudflare DNS + CNAME instead of a tunnel process at all (see option 4 in the script, or the details in the script output).

## Recommended Alternative: Native Cloudflare + Fly Custom Domain (Simpler for Fly)
- In Fly: `fly certs create yourdomain.com -a nodecast-tv-zsivasto` (or via dashboard)
- In Cloudflare DNS for your domain: CNAME `live` -> `nodecast-tv-zsivasto.fly.dev` (enable orange cloud / proxy)
- In CF SSL/TLS: set to "Full" or "Full (strict)"
- This gives you yourdomain.com with CF security in front of Fly, no tunnel process needed.
- Fly will handle the cert too (or let CF do SSL).

## Next Steps After CF URL Works
- Visit the CF URL, create your first admin user
- Settings > Transcoding: Hardware Encoder=software, Max Resolution=720p, Quality=low (Fly free tier limits)
- Add your Xtream/M3U sources
- Test live TV / #live section
- (Optional) Lock down in Fly if needed (but public PaaS)

## Oracle Path Reminder
Still available if you want bigger free VM later.

Update this file or the CLOUDFLARE_DEPLOY_STEPS.md as we go. Paste output/errors from the commands above.

## Progress 2026-06-04 (continued) - Code fixes + Deploy + Cloudflare next
- Reviewed running app logs: transcode sessions failing with "Error opening input file /api/proxy/stream?..." because frontend was passing proxied client URL (meant for browser playback) as the *source* to /api/transcode/session and legacy transcode.
- Fixed in both Live TV (VideoPlayer.js) and VOD/Series (WatchPage.js): now always pass original source URL to startTranscodeSession / remux constructions. Proxy wrapper only used for final client-facing playback URLs (video.src / hls.loadSource).
- This matches the architecture: server-side ffmpeg always pulls original media (using its -user_agent + reconnect flags); the /api/proxy is only to let the *browser* reach http sources or bypass provider CORS when loading processed or raw streams.
- Committed + pushed the fix + all prior uncommitted work (proxy UA improvements, binary streaming without full buffer to prevent OOM, subtitle, db, EPG, settings, etc.) to myfork main.
- Triggered `fly deploy` (build context sent; new image will have the transcode fix).
- After deploy succeeds, the app at https://nodecast-tv-zsivasto.fly.dev will have working transcoding for incompatible audio (eac3 etc) and VOD seeking via HLS sessions.
- Next: run the Cloudflare helper to get a nice trycloudflare.com (or named) front for the app.

## Immediate next commands (paste/run in terminal)
```bash
cd /Users/steve/nodecast-tv

# Check deploy finished (or tail the bg task if using harness)
fly status -a nodecast-tv-zsivasto
fly logs -a nodecast-tv-zsivasto --no-tail | tail -20

# Start quick Cloudflare front (ephemeral but instant, no login):
./setup-fly-cloudflare-tunnel.sh
# Choose option 1, keep the process running in that terminal.
# It will print a https://random.trycloudflare.com  -- visit it, append #live if needed.
```

(If deploy still running in background here, wait for it or run `fly deploy` yourself.)

After CF URL loads:
- If first run on this volume: create admin account.
- Settings > Transcoding: set Hardware=software, Max Res=720p, Quality=low (important for 1CPU free tier).
- Add a content source if not already (the local data/ had some, but volume is fresh?).
- Test a channel that needs audio transcode (many have eac3), or a VOD series/movie.
- Check Settings > About for version info (we added that earlier).

Useful:
fly ssh console -a nodecast-tv-zsivasto   # then cd /app ; ls data/ ; tail -f /app/data/content.db-wal or just use the web UI logs? No, app has no built-in log viewer yet.

## Cloudflare Quick Tunnel Started (this session)
- Ran: cloudflared tunnel --url https://nodecast-tv-zsivasto.fly.dev
- Public URL (ephemeral, valid while the tunnel process runs): https://infants-recognize-tolerance-announces.trycloudflare.com
- Verified: curl returns 200, CF headers present (cf-ray etc).
- App is reachable via Cloudflare front-end right now (in this environment's bg tunnel).

**For you (user) to access right now:**
1. In *your* terminal (on your Mac):
   ```bash
   cd /Users/steve/nodecast-tv
   ./setup-fly-cloudflare-tunnel.sh
   # pick 1 for quick (or 2 for named after login)
   ```
   Or directly:
   ```bash
   cloudflared tunnel --url https://nodecast-tv-zsivasto.fly.dev
   ```
   Keep that terminal open. Copy the printed https://*.trycloudflare.com link.
2. Visit the link in browser. It may take 10-30s first time to be ready.
3. Create admin if prompted (first visit to fresh volume).
4. Configure transcoding for free tier as noted.
5. Add sources via Settings > Content Sources > Refresh.

**To stop the tunnel (when done testing):** Ctrl+C in its terminal, or `pkill -f cloudflared`.

**For persistent/no-Mac-running:**
- Use option 4 in the script (CNAME to yourdomain via Cloudflare DNS, orange cloud).
- Or move cloudflared inside the Fly machine (we can add to Dockerfile if wanted: install cloudflared, run as side process or use fly's own? but Fly has its proxy already).

App is now in good shape with the source-URL fix deployed (machine version 13).

