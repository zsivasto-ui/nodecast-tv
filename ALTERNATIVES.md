# Free Hosting Alternatives to Oracle Cloud Always Free (2026)

Oracle Always Free gives you a real powerful VM (Ampere A1 with lots of CPU/RAM) that you control completely — ideal for FFmpeg video transcoding in nodecast-tv.

Here are **different** options (mostly easier PaaS with Git/Docker deploys). They are free or have generous free tiers but usually have **smaller resources** (transcoding will be slow), **sleep/cold-starts**, or usage limits. Great for personal/testing use.

We prepared some configs already:
- `render.yaml`
- `fly.toml`

## Top Recommendations (Different from Oracle VM)

1. **Render.com** (Easiest for beginners)
   - Free: 750 hours/month web services (Docker or auto-detect Node).
   - Sleeps after 15 min idle (30-60s cold start).
   - 512MB RAM / 0.1 vCPU on free.
   - No credit card for free tier.
   - Persistent disk for /app/data.
   - Link: https://render.com
   - How: New Web Service → connect GitHub (use Dockerfile or the render.yaml here).

2. **Fly.io** (Best Docker / global)
   - Free allowances: e.g. equivalent of a few 256MB shared machines (can run 24/7 within quota) + volumes.
   - Full Docker/Machines support.
   - Global regions.
   - fly.toml already in project.
   - Link: https://fly.io
   - How: Install flyctl, `fly launch` (detects Dockerfile), `fly deploy`. Add volume for data.

3. **Koyeb** (Good no-CC free tier)
   - Free: 1 web service (Eco: 0.1 vCPU, 512MB RAM, 2GB SSD) + limited free Postgres.
   - Scale-to-zero (wakes on traffic).
   - Docker images or Git.
   - No credit card for basic free.
   - Link: https://www.koyeb.com (signup at app.koyeb.com/auth/signup)
   - How: New Service from GitHub repo + Dockerfile. Use free Eco instance.

4. **Northflank**
   - Free Developer plan: Multiple services, jobs, Docker, Git deploys, volumes.
   - Often less aggressive sleeping than Render.
   - Credit card on signup (not charged on free).
   - Link: https://northflank.com (app.northflank.com/signup)
   - How: New project/service from Git + Dockerfile, mount storage for /app/data.

5. **IBM Cloud (Lite / Always Free services)**
   - 40+ always-free Lite plans (no expiration on many).
   - Containers via Code Engine, VMs, etc.
   - No credit card for Lite account.
   - Smaller instances than Oracle but "always free" vibe.
   - Link: https://cloud.ibm.com/registration
   - How: Use Code Engine for Docker containers or create a free VM.

6. **Google Cloud (Cloud Run or e2-micro)**
   - Cloud Run: Free tier (millions of requests + vCPU-seconds per month), serverless containers (Docker perfect).
   - Always Free e2-micro VM in some regions.
   - Good for containers but request-based (not ideal for long streaming?).
   - Link: https://console.cloud.google.com/

## Important for nodecast-tv
- **FFmpeg transcoding**: Will be very slow on free PaaS tiers (0.1 vCPU). Stick to low resolution + "software" encoder in Settings → Transcoding. Oracle VM or a cheap $3-5/mo VPS is much better for real use.
- Push your code (with About page + VOD subtitle fixes) to GitHub first.
- Use persistent volumes/disks for `/app/data`.
- Test with the existing render.yaml or fly.toml.

For the absolute best free experience (powerful always-on VM like Oracle but different provider), IBM Cloud or GCP VM free tiers are closest. For simplicity, start with Render or Koyeb.

See full details and steps in DEPLOY.md.

## After 90 Days on GCP?

**Yes, it keeps working at $0.**

The page you saw during signup advertises a **$300 90-day trial credit**. This is temporary "play money" for testing paid services.

The resources we use (e2-micro VM and Cloud Run free quotas) belong to the separate **Always Free** tier, which:
- Never expires
- Has monthly limits (1 e2-micro VM + 30GB disk in specific regions, plus Cloud Run requests/CPU)
- Costs nothing as long as you stay inside the limits

The gcp-deploy.sh script sets up billing alerts at $1 and targets only Always Free resources.

After the 90 days:
- Your deployed app (VM or Cloud Run) continues running.
- No auto-charges or shutdown.
- Just don't exceed the free allowances (the script and docs warn about this).

For nodecast-tv this is reliable for personal/low-traffic use. Heavy transcoding or many simultaneous users may need a cheap paid upgrade later, but the free tier itself doesn't disappear.

See the full "after 90 days" explanation in DEPLOY.md.
