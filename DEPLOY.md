# Deploy nodecast-tv Online (Free Hosting Options)

**Important warnings:**
- This is an IPTV player. Make sure you have rights to the streams you add.
- Free hosting has limits: CPU, RAM, bandwidth (egress). Transcoding video is CPU-heavy; expect software encoding on free tiers. Multiple simultaneous streams may be slow or hit limits.
- Always enable authentication (users in Settings).
- Use HTTPS in production.
- Oracle Cloud is the best "always free + always on" option for this app.

## Recommended: Oracle Cloud Always Free (Best for this app)

Oracle gives you a real VM (Ampere A1: up to 4 vCPU + 24 GB RAM free forever, shared). Public IP. Full Linux. Perfect for Node + FFmpeg.

### Step 1: Sign up
1. Go directly to the signup page: https://signup.cloud.oracle.com/
2. Or visit the info page first: https://www.oracle.com/cloud/free/
3. Sign up with email. You'll need a credit card for identity verification only (you won't be charged for Always Free resources).
3. Verify email and complete account setup. It can take a few minutes to hours for approval sometimes.

### Step 2: Create a VM (Ampere A1 recommended)
1. In Oracle Cloud Console → Compute → Instances → Create Instance.
2. Name: `nodecast-tv`
3. Image: Ubuntu 24.04 (or latest Minimal aarch64).
4. Shape: 
   - Select "Ampere" → `VM.Standard.A1.Flex`
   - Set OCPU: 4 (or max available in free tier)
   - Memory: 24 GB
5. Networking: Create new VCN or use default. **Important**: In the subnet security list, allow ingress TCP 3000 (or 80/443 later).
6. Add SSH key (generate one if needed: `ssh-keygen`).
7. Create.

Note the public IP.

### Step 3: SSH into the VM and prepare
```bash
ssh -i your-key.pem ubuntu@YOUR_PUBLIC_IP
```

Update system:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ca-certificates gnupg lsb-release
```

Install Docker:
```bash
# Official Docker install for Ubuntu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
# Log out and back in, or:
newgrp docker
```

Verify:
```bash
docker --version
docker compose version
```

### Step 4: Deploy the app

**Option A: Simple docker compose (quick)**

```bash
git clone https://github.com/YOUR_USERNAME/nodecast-tv.git   # or your fork
cd nodecast-tv

# Edit docker-compose.yml for production
nano docker-compose.yml
```

Example improved `docker-compose.yml` (use this):
```yaml
services:
  nodecast-tv:
    build: .
    # or image: ghcr.io/technomancer702/nodecast-tv:latest  (if using original)
    container_name: nodecast-tv
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
      - ./transcode-cache:/app/transcode-cache   # optional
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=3000
    # For better performance on free tier (software encode)
    # No GPU on free Oracle usually
```

Start:
```bash
docker compose up -d --build
```

Check logs:
```bash
docker compose logs -f
```

Access: `http://YOUR_PUBLIC_IP:3000`

**Security first:**
- Open Oracle security list for TCP 3000 from your IP only (or use Cloudflare Tunnel below).
- In the app (after first login): Go to Settings → create admin user immediately.

### Step 5: Make it nice (HTTPS + nice domain) - Recommended

Use **Cloudflare Tunnel** (free, no open ports on Oracle, automatic HTTPS, works great behind CGNAT/firewalls). This is the best way to "host it to Cloudflare".

There's a helper script included in the repo: `setup-cloudflare-tunnel.sh`.

On the VM (after the app is running with `docker compose up -d --build`):

```bash
chmod +x setup-cloudflare-tunnel.sh
./setup-cloudflare-tunnel.sh
```

The script will:
- Install cloudflared (arm64 version for Oracle Ampere)
- Offer a quick one-command temporary public URL (`https://...trycloudflare.com`)
- Guide through permanent named tunnel + optional custom domain
- Optionally set it up as a systemd service

Manual steps (if you prefer not to use the script):

1. On the VM:
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

2. Login and create tunnel (follow https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/ ):
```bash
cloudflared tunnel login
cloudflared tunnel create nodecast
cloudflared tunnel route dns <tunnel-id> tv.yourdomain.com   # or use a free *.trycloudflare.com
cloudflared tunnel run nodecast
```

Or run as service with config that points to `http://localhost:3000`.

Alternative: Install Nginx + certbot on the VM and point a domain A record to the public IP, open ports 80/443.

### Using Coolify (Nicer UI, like Heroku)

On the same Oracle VM:
```bash
curl -fsSL https://get.coolify.io/ | bash
```

Then open `http://YOUR_IP:8000`, create admin, connect your GitHub (fork the repo or push your changes), add the project as Docker, set volume for /app/data, deploy.

Coolify handles updates, logs, env, domains easily.

## Other Free Options (Different from Oracle Always-Free VM)

Oracle gives you a powerful full VM (Ampere A1 up to 4vCPU/24GB usable) that you fully control — great for FFmpeg transcoding and always-on. Most PaaS alternatives are easier to deploy but have trade-offs: smaller resources (slow FFmpeg on free tiers), sleep/cold-starts, or usage caps. They are good for testing or light personal use.

We already prepared configs for some (render.yaml, fly.toml in the project root).

### Comparison of Top Alternatives (2026 info)

| Platform     | Free Tier Highlights                          | Docker | Sleep/Cold Start | CPU/RAM on Free (typical) | Credit Card? | Best For                  | Signup Link                     |
|--------------|-----------------------------------------------|--------|------------------|---------------------------|--------------|---------------------------|---------------------------------|
| **Render**  | 750 hrs/mo web services (enough for ~1 always if lucky) | Yes (Dockerfile or auto) | Yes (15min idle, ~30-60s wake) | 512MB / 0.1 vCPU | No for free | Easiest Git/Docker deploys | https://render.com             |
| **Fly.io**  | Free allowances (~3x 256MB shared machines can run 24/7 within quota) + volumes | Excellent (Machines) | Can autostop; within allowance ~always | Shared 256MB+ | Often yes (for billing) | Global edge, full Docker control | https://fly.io                 |
| **Koyeb**   | 1 free web service (Eco: 0.1vCPU/512MB) + limited free Postgres | Yes (Git or Docker image pull) | Scale-to-zero (wakes fast) | 0.1 vCPU / 512MB | No (for basic free) | Simple serverless containers | https://www.koyeb.com (app.koyeb.com/auth/signup) |
| **Northflank** | Free Developer: 2 services + jobs, Docker, Git, volumes | Yes | No forced sleep in dev plan (per docs) | Limited but usable for small | Yes (but not billed on free) | Nice DX + BYOC option | https://northflank.com (app.northflank.com/signup) |
| **IBM Cloud** | 40+ always-free services (no time limit, Lite plans) + $200 trial credit | Yes (Code Engine containers, VMs) | Varies | Lite plans are small | No (Lite) | Generous always-free like Oracle (but different services) | https://cloud.ibm.com/registration |
| **GCP**     | Cloud Run free (2M requests/mo + compute seconds), e2-micro VM always-free tier | Excellent (Cloud Run) | Scale-to-zero | Request-based or micro VM | Usually yes | Serverless containers | https://console.cloud.google.com/ |

**Notes for this app:**
- **FFmpeg transcoding** will be slow or limited on all PaaS free tiers (tiny CPU). Use "software" encoder + lower resolution in Settings. For serious use, Oracle VM or cheap paid VPS wins.
- Persistent storage: Use platform volumes/disks for `/app/data`.
- Bandwidth: Free tiers cap egress (video streaming eats it).
- Always push your local changes (including VOD subtitle fix + About page) to a GitHub fork/repo first.

### Render.com (Easiest — we have render.yaml ready)
1. Fork/push code to GitHub.
2. https://render.com → New → Web Service → connect repo.
3. Environment: Docker. It will use the Dockerfile (or our render.yaml blueprint).
4. Add a Persistent Disk mounted at `/app/data`.
5. Deploy. Free tier will sleep — access wakes it (expect delay first time).

Existing `render.yaml` in the project helps with config.

### Fly.io (Great Docker support — fly.toml ready)
```bash
curl -L https://fly.io/install.sh | sh
fly auth login
fly launch   # detects Dockerfile, uses fly.toml
fly deploy
fly volumes create nodecast_data --size 1   # for /app/data
# Then attach in fly.toml or dashboard
```

Use the existing `fly.toml`. Free allowances let some machines run without sleeping if under quota.

### Koyeb (Simple free tier)
1. Sign up at https://www.koyeb.com (or direct app signup).
2. New Service → GitHub repo or Docker image.
3. Use the project's Dockerfile. It detects and gives a free Eco service (0.1 vCPU/512MB).
4. Add volume for data if needed (paid beyond free?).
5. Deploy. Free tier is one service.

Good no-CC option for basic free web service.

### Northflank
1. https://app.northflank.com/signup (card for signup but free tier not billed).
2. New project/service from GitHub + Dockerfile.
3. Free Developer plan gives multiple services + storage options.
4. Set persistent volume for `/app/data`.
5. Git push deploys.

Often praised as better free tier than Render (less aggressive sleeping).

### Google Cloud Platform (GCP) - Free Tier (Cloud Run or e2-micro VM)
GCP free tier is excellent for containers. Two main paths:

**A. Cloud Run (serverless, easiest, generous free quota: 2M requests/mo + CPU/memory seconds)**
- Perfect for the Dockerfile.
- Stateless: /app/data (SQLite) will reset on new instances/revisions unless you add Cloud Storage FUSE mount (advanced).
- Scale to zero = no cost when idle.

**B. Compute Engine e2-micro VM (always free in us-central1/us-east1/us-west1, 1 vCPU burst / 1GB RAM, persistent disk)**
- More like Oracle: full control, can run Docker persistently.
- Limited RAM (may struggle with heavy transcoding + multiple streams).

**Setup steps (after gcloud installed - we just did via brew):**

1. Go to https://console.cloud.google.com and sign in / create account (free tier auto).
2. Create a new project (or use default). Note the Project ID.
3. In console, go to Billing (even for free tier, link a billing account - you won't be charged under free quota).
4. In terminal (we added gcloud to PATH):
   ```bash
   export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"
   gcloud auth login   # Opens browser to console.cloud.google.com - complete login
   gcloud init         # Select/create project, set default region (e.g. us-central1)
   ```
5. Use the helper script we created:
   ```bash
   cd nodecast-tv
   ./gcp-deploy.sh [your-project-id] [region e.g. us-central1]
   ```
   The script will:
   - Create/select project
   - Enable necessary APIs (Run, Compute, Artifact Registry)
   - Offer Cloud Run or VM deploy
   - For VM: creates e2-micro + persistent disk instructions
   - For Cloud Run: deploys directly from source (builds image for you)

**Manual Cloud Run deploy (if skipping script):**
```bash
gcloud run deploy nodecast-tv \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --port 3000
```

**For persistence on Cloud Run (optional advanced):**
Mount a GCS bucket at /app/data using gcsfuse (add to Dockerfile or sidecar). See GCP docs for "Cloud Run with Cloud Storage FUSE".

**Firewall / access:**
- Cloud Run gives public URL automatically.
- For VM: script sets up http-server tag; add firewall rule for port 80/3000 if needed.

**Free tier notes:**
- Stay under quotas (monitor in console > Billing > Reports).
- e2-micro is burstable and limited; good for light personal use.
- First deploys may take time to build.

**Next in console:**
- https://console.cloud.google.com/run (for Cloud Run services)
- https://console.cloud.google.com/compute (for VMs)
- Enable "Free tier" tracking.

We also have the gcp-deploy.sh ready with both options.

If you hit any error during gcloud init or the script, paste it here and I'll fix. 

After login in browser, run `gcloud init` and then the deploy script. This gets you a public URL quickly.

See their "Always Free" tab after signup.

### Will it work after the 90-day $300 credit?
**Yes — the parts we use will keep working indefinitely at $0.**

- The $300 credit is a **separate 90-day trial** to experiment with paid services. It has nothing to do with the Always Free tier.
- The resources we target (e2-micro VM in specific regions + Cloud Run free quota) are part of Google's **Always Free** program.
- Always Free has **no expiration**. You get monthly usage allowances forever (e.g., one e2-micro VM + 30GB disk + limited egress).
- As long as you stay within the monthly limits and only use Always Free resources, your bill stays $0 forever.
- The script automatically sets up a $1 billing alert so you get warned long before any possible charge.
- After 90 days: Nothing breaks. Your VM/container keeps running. You just can't use paid resources beyond the free allowances without upgrading (which you don't have to do).

**Recommendation for your app:**
- Choose the **VM option (b)** in the script. It gives you a real persistent disk at `/mnt/data/data` mounted to `/app/data` so your SQLite database, sources, users, and favorites survive restarts/reboots — exactly like Oracle.
- Cloud Run (option a) is easier but the data dir is ephemeral by default.

**To stay safe forever:**
- Only run one e2-micro instance.
- Monitor usage: https://console.cloud.google.com/billing
- Keep the $1 alert enabled.
- For FFmpeg: Stick to software encoding + lower resolutions in your app's Transcoding settings (e2-micro is low-power).

If you ever want more power, you can easily resize the VM or add paid resources later without losing your data.

This is why we picked the e2-micro path — it's the closest "set and forget" free hosting to Oracle's Always Free.

### Quick Self-Hosted Alternative (Cheap + Powerful)
Instead of pure free PaaS, get a $3-6/mo VPS (Hetzner, OVH, DigitalOcean, etc.) and install **Coolify** (Heroku-like UI):
```bash
curl -fsSL https://get.coolify.io/ | bash
```
Then deploy from Git with volumes — full control, no sleeping, cheap.

## After Deployment (any platform)
... (rest of section stays similar)

## After Deployment

1. **First access**: Create admin user via the login/create account flow.
2. **Add sources**: Settings → Content Sources → Add your Xtream or M3U.
3. **Security**:
   - Change default port if wanted (env PORT).
   - Use strong passwords.
   - Consider OIDC if you have Authentik/Keycloak elsewhere.
   - Firewall: Only allow needed ports.
4. **Performance**:
   - On free VMs: Stick to "software" encoder.
   - Lower max resolution in Settings → Transcoding.
   - Enable "Auto Transcode" smart.
   - For many users: Not suitable on free tier.
5. **Persistence**: Make sure `./data` volume is backed (Oracle block volume is persistent).
6. **Updates**: Pull latest, `docker compose up -d --build`.

## Pushing your local changes (including the subtitle fix)

Since you have local edits:
```bash
cd nodecast-tv
git remote add origin https://github.com/YOUR_USERNAME/nodecast-tv.git
git add .
git commit -m "Add VOD subtitle support and other local changes"
git push -u origin main
```

Then use that repo for deploys above.

## Need help?

- Oracle signup issues: Common, search "Oracle Cloud free tier approval".
- For production video use, consider a cheap paid VPS ($3-6/mo from Hetzner, OVH, etc.) instead of free for better performance/reliability.
- Bandwidth note: Streaming 1080p uses ~2-5 Mbps per user. Free tiers have monthly caps.

Enjoy your online nodecast-tv!

## Clarification on Google Cloud "Free" Offer (from the signup page you saw)

The page you quoted is the **standard new customer signup screen**. It combines two things:

1. **$300 free credit (90-day trial)**: This is "play money" to try any Google Cloud products (including paid ones) without cost. 
   - You will **NOT** be automatically charged after 90 days.
   - You only start paying if you **manually upgrade** to a full pay-as-you-go account or exceed the trial credit.
   - Any unused credit is just lost after 90 days.

2. **Always Free tier** (the important part for us): These are products you can use **forever** at no cost, up to monthly limits. The $300 credit is **not** used for Always Free usage.

Relevant Always Free for nodecast-tv:
- **Compute Engine**: 1 × e2-micro VM (1 vCPU burst, 1 GB RAM) in us-central1, us-east1 or us-west1 + 30 GB standard persistent disk + 1 GB egress/month. This is the closest to Oracle's always-free VM.
- **Cloud Run**: 2 million requests/month + CPU/memory seconds (great for the Docker container, scale-to-zero).
- Other storage, etc.

**Key reality**:
- You **must** add a payment method (credit/debit card) and create a billing account to use Google Cloud at all (even free tier). This is required for the signup.
- As long as you **only use Always Free resources** and stay under the limits, your bill will be $0 forever.
- **Recommendation**: After creating the billing account, immediately set up **billing alerts** (e.g., at $1, $5, $10) in the console so you get emails if anything goes over.
- For our app: Use the e2-micro VM for persistent storage (your SQLite DB in /app/data) and full FFmpeg control. Cloud Run is easier but the data directory is ephemeral unless you mount Cloud Storage.

The script `./gcp-deploy.sh` is designed to use only Always Free resources.

**Important**: Complete the console signup (accept TOS + billing account) **before** running the script again. The previous run failed on "Terms of Service".

