# Hosting nodecast-tv to Cloudflare (Oracle + Tunnel)

> **Note for current Fly.io deployment**: If you are using the live Fly app (nodecast-tv-zsivasto.fly.dev), use the Mac-friendly helper instead:
>   cd nodecast-tv && ./setup-fly-cloudflare-tunnel.sh
> It supports quick trycloudflare URLs and the simpler Cloudflare DNS CNAME method (often best when the app is already on a public PaaS like Fly). The Oracle-focused steps below are still valid if you switch to an Always-Free VM later.

This file was prepared for you in the workspace.

## Prerequisites (do this first on your local machine)

1. On GitHub.com:
   - Fork https://github.com/zsivasto-ui/nodecast-tv to your account, OR create a new empty repo called "nodecast-tv".

2. In this terminal (the one with the nodecast-tv folder), push your local work (includes all recent improvements + the deploy scripts):

```bash
# Use your own fork URL if different
git remote add myfork https://github.com/zsivasto-ui/nodecast-tv.git

# Authenticate if needed (use GitHub token or SSH key)
git push -u myfork main
```

After this, your repo URL will be:
https://github.com/zsivasto-ui/nodecast-tv

## Step 1: Create the Oracle Cloud Always Free VM

1. Go to https://signup.cloud.oracle.com/ and complete signup (you'll need a credit card for identity verification only — you won't be charged for Always Free resources).

2. In the Oracle Cloud Console:
   - Go to **Compute > Instances > Create Instance**
   - Name: `nodecast-tv`
   - **Image and shape**:
     - Operating System: Ubuntu 24.04 (Minimal)
     - Architecture: aarch64 (important)
     - Shape: Select **Ampere** → `VM.Standard.A1.Flex`
       - OCPU: 4 (or the maximum available in free tier for that region)
       - Memory: 24 GB
   - Networking: Use default or create VCN. **Temporarily** allow ingress on ports 22 (SSH) and 3000 (you will close 3000 later).
   - Add SSH key: Generate one locally if you don't have (`ssh-keygen -t ed25519`), then paste the public key.
   - Create the instance.

3. Note the **Public IP address**.

If you get "Out of capacity" error, try a different region (e.g., Ashburn, Frankfurt, London, Montreal often have capacity for free Ampere instances).

## Step 2 + 3: Deploy on the VM + Cloudflare Tunnel (one command)

SSH into the VM:

```bash
ssh -i ~/.ssh/your-oracle-key ubuntu@YOUR_VM_PUBLIC_IP
```

Then run these three commands (copy-paste):

```bash
# Download the all-in-one deploy script
curl -fsSL https://raw.githubusercontent.com/zsivasto-ui/nodecast-tv/main/oracle-cloudflare-deploy.sh -o deploy.sh

# Make executable and run (pass your GitHub repo URL)
chmod +x deploy.sh
./deploy.sh https://github.com/zsivasto-ui/nodecast-tv.git nodecast-tv
```

The script will:
- Install system updates + Docker
- Clone your repo
- Build and start nodecast-tv (`docker compose up -d --build`)
- Launch the interactive Cloudflare Tunnel setup

When the tunnel script runs, follow its prompts. It will give you a public HTTPS URL (trycloudflare.com for quick test, or your custom domain).

## After the script finishes

1. Open the URL the tunnel gave you in your browser.
2. Create your first admin account.
3. Go to **Settings > Transcoding** and set:
   - Hardware Encoder: `software`
   - Max Resolution: `720p` (or `480p` for lighter use)
   - Quality: `low`
4. Add your content sources.

## Security hardening (do this)

Once the Cloudflare Tunnel is working and you can access the app:
- In Oracle Console → Networking → Virtual Cloud Networks → your VCN → Security Lists
- Edit the security list:
  - Remove or disable the rule allowing TCP 3000 from anywhere.
  - Keep only TCP 22 (SSH) from **your specific IP** (or a small range).
- This way the only way to reach the app is through Cloudflare.

## Useful commands on the VM

```bash
# App logs
cd nodecast-tv
docker compose logs -f

# Restart / update
docker compose up -d --build

# Tunnel service status (if you set it up as service)
sudo systemctl status cloudflared-nodecast-tv
journalctl -u cloudflared-nodecast-tv -f
```

## Notes

- The first sync of a large provider may take time and use memory/CPU. Use "software" + low settings.
- Transcode cache is ephemeral by default (fine).
- Persistent data lives in the `./data` volume on the VM disk.
- For even easier management later, you can install Coolify on the same VM.

This gets your nodecast-tv fully hosted and accessible via Cloudflare.

If you run into any errors during the VM creation or script, paste them here and I'll help fix immediately.