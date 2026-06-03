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

## Next Session
- Start here: cd /Users/steve/nodecast-tv
- Resume Fly deploy + volume + tunnel as above.
- Or switch to new Oracle account + Ashburn if preferred.
- Paste any errors/screenshots and we'll continue.

Everything is saved in your GitHub repo + this file. See you later!
