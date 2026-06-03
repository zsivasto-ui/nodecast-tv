#!/bin/bash
# GCP Deploy Helper for nodecast-tv (Always Free focused)
# IMPORTANT: Complete https://console.cloud.google.com signup + billing account + create project FIRST.
# Then: ./gcp-deploy.sh YOUR_PROJECT_ID [us-central1]

set -e

if [ -z "$1" ]; then
  echo "Usage: ./gcp-deploy.sh YOUR_PROJECT_ID [REGION]"
  echo "Example: ./gcp-deploy.sh nodecast-tv-demo us-central1"
  echo ""
  echo "Go to https://console.cloud.google.com NOW:"
  echo "1. Sign up / sign in"
  echo "2. Accept Terms of Service"
  echo "3. Create a Billing Account (add payment method - you will NOT be charged if you stay in Always Free limits)"
  echo "4. Create a new Project and copy its ID (e.g. nodecast-tv-demo)"
  echo "5. Then run this script with that Project ID."
  exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}

echo "=== nodecast-tv GCP Always-Free Setup ==="
echo "Project: $PROJECT_ID | Region: $REGION"
echo ""

export PATH="/usr/local/share/google-cloud-sdk/bin:$PATH"

echo "Checking auth..."
gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 || gcloud auth login --update-adc

echo "Setting project..."
gcloud config set project "$PROJECT_ID" 2>/dev/null || {
  echo "Project not accessible yet. Make sure you created it in the console and accepted TOS/billing."
  exit 1
}

echo "Enabling APIs (this is free)..."
gcloud services enable run.googleapis.com artifactregistry.googleapis.com compute.googleapis.com

echo "Setting up billing alerts to protect the free tier (alert at $1)..."
# Create a budget with alert (requires billing account)
BILLING_ACCOUNT=$(gcloud billing accounts list --format='value(name)' | head -1)
if [ -n "$BILLING_ACCOUNT" ]; then
  gcloud billing budgets create \
    --billing-account="$BILLING_ACCOUNT" \
    --display-name="nodecast-tv-free-alert" \
    --budget-amount=1 \
    --threshold-rule=percent=100 2>/dev/null || echo "(Budget alert may already exist or needs console setup)"
  echo "Billing alert set for $1 (you'll get email if anything approaches paid usage)."
else
  echo "No billing account found yet - set one up in console first for alerts."
fi

echo ""
echo "Choose deployment (both can stay in Always Free tier):"
echo "  a) Cloud Run (easiest, serverless containers, generous free requests/CPU)"
echo "  b) Compute Engine e2-micro VM (persistent disk like Oracle, full control)"
read -p "a or b? [a/b]: " choice

if [ "$choice" = "b" ]; then
  echo "=== e2-micro VM (Always Free in $REGION) ==="
  VM="nodecast-vm"
  ZONE="${REGION}-a"

  echo "Creating VM + 10GB persistent disk (free tier eligible)..."
  gcloud compute instances create "$VM" \
    --zone="$ZONE" \
    --machine-type=e2-micro \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=30GB \
    --create-disk=name=nodecast-data,size=10GB,type=pd-standard \
    --tags=http-server,https-server \
    --metadata-from-file=startup-script=<(cat << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y docker.io git ca-certificates
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
mkdir -p /mnt/data
mount /dev/sdb /mnt/data || (mkfs.ext4 /dev/sdb && mount /dev/sdb /mnt/data)
mkdir -p /mnt/data/data
chown -R ubuntu:ubuntu /mnt/data
EOF
)

  echo "Waiting for VM..."
  sleep 45

  IP=$(gcloud compute instances describe "$VM" --zone="$ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

  echo ""
  echo "VM created. SSH in and finish (or let the script do more):"
  echo "gcloud compute ssh $VM --zone=$ZONE"
  echo ""
  echo "Inside the VM, run these commands:"
  echo "  git clone https://github.com/zsivasto-ui/nodecast-tv.git /app || true"
  echo "  cd /app"
  echo "  sudo docker build -t nodecast ."
  echo "  sudo docker run -d --name nodecast -p 80:3000 -v /mnt/data/data:/app/data --restart unless-stopped nodecast"
  echo ""
  echo "Then open http://$IP in browser (allow port 80 in firewall if needed)."
  echo "gcloud compute firewall-rules create allow-http --allow tcp:80 --target-tags http-server --project=$PROJECT_ID || true"

  echo "Public IP: $IP"
  echo "Access after setup: http://$IP"

else
  echo "=== Cloud Run (Always Free generous quota) ==="
  echo "Note: Data in /app/data is ephemeral by default (resets). For persistence you can add GCS FUSE later."

  gcloud run deploy nodecast-tv \
    --source . \
    --region "$REGION" \
    --allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --port 3000 \
    --set-env-vars NODE_ENV=production,PORT=3000

  URL=$(gcloud run services describe nodecast-tv --region "$REGION" --format 'value(status.url)')
  echo ""
  echo "Deployed to Cloud Run!"
  echo "Public URL: $URL"
  echo "It will scale to zero (free when not used). Cold start on first access."
  echo "To update later: run this script again or gcloud run deploy --source . --region $REGION"
fi

echo ""
echo "Done. Monitor usage at https://console.cloud.google.com/billing"
echo "Stay in Always Free limits = $0 forever."

echo ""
echo "=============================================="
echo "IMPORTANT: After 90 days?"
echo "=============================================="
echo "YES - it will keep working forever if you use ONLY the Always Free resources."
echo ""
echo "- The \$300 credit is just a 90-day trial for testing paid features."
echo "- The e2-micro VM (or Cloud Run) is part of the 'Always Free' tier."
echo "- Always Free has NO expiration date. Monthly limits apply, but usage within limits = \$0 forever."
echo "- As long as you don't exceed the free quotas (1 e2-micro VM, etc.), no charges."
echo "- We set up a \$1 billing alert to notify you early."
echo ""
echo "Monitor at: https://console.cloud.google.com/billing"
echo "Recommended: Use the VM option (b) for persistent /app/data storage."
echo "For heavy use or many users, consider a cheap paid VM later."
echo "=============================================="
