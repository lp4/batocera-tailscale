#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Smarter Auth Key Logic ---
if [ -n "$1" ]; then
  TAILSCALE_AUTH_KEY="$1"
  echo "Using auth key provided as a command-line argument."
elif [ -t 0 ]; then
  read -p "Please enter your Tailscale auth key: " TAILSCALE_AUTH_KEY
else
  echo "Error: Not running in an interactive terminal." >&2
  echo "Please provide the auth key as an argument to the script." >&2
  echo "Example: curl ... | bash -s -- \"YOUR_AUTH_KEY\"" >&2
  exit 1
fi

if [[ -z "$TAILSCALE_AUTH_KEY" ]]; then
    echo "Error: Auth key was not provided. Exiting." >&2
    exit 1
fi

echo "Running Tailscale install script..."

# --- 1. Determine System Architecture (User's Original Method) ---
echo "Detecting system architecture..."
arch=""
if [[ "$(uname -m)" == "x86_64" ]]; then
        arch="386"
fi
if [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
fi
if [[ "$(uname -m)" == "aarch32" ]]; then
        arch="arm"
fi
if [[ "$(uname -m)" == "amd64" ]]; then
        arch="amd64"
fi
if [[ "$(uname -m)" == "riscv64" ]]; then
        arch="riscv64"
fi
if [[ "$(uname -m)" == "x86" ]]; then
        arch="386"
fi
if [[ "$(uname -m)" == "armv7l" ]]; then
        arch="arm"
fi

sleep 5

# Finding Architecture.
case ${arch} in
  386)
    arch="386"
    echo "supported tailscale zip $arch"
    ;;
  arm64)
    arch="arm64"
    echo "supported tailscale zip $arch"
    ;;
  arm)
    arch="arm"
    echo "supported tailscale zip $arch"
    ;;
  amd64)
    arch="amd64"
    echo "supported tailscale zip $arch"
    ;;
  riscv64)
    arch="riscv64"
    echo "supported tailscale zip $arch"
    ;;
  386)
    arch="386"
    echo "supported tailscale zip $arch"
    ;;
  *)
    if [ -z "$arch" ]; then
      echo "Error: Architecture could not be determined." >&2
      exit 1
    fi
    ;;
esac


# --- 2. Stop and Disable Existing Tailscale Service ---
echo "Stopping and disabling any existing Tailscale service..."
batocera-services stop tailscale || true
batocera-services disable tailscale || true

# --- 3. Download and Install Tailscale ---
echo "Creating temporary directory for download..."
rm -rf /userdata/temp
mkdir -p /userdata/temp
cd /userdata/temp

echo "Downloading Tailscale for your system..."
# NOTE: The original script used 1.80.0. I am using a newer version for security/features.
# If you need the exact older version, change 1.88.3 to 1.80.0 in the next two lines.
wget -q "https://pkgs.tailscale.com/stable/tailscale_1.88.3_${arch}.tgz"

echo "Extracting and installing files..."
tar -xf "tailscale_1.88.3_${arch}.tgz"
cd "tailscale_1.88.3_${arch}"

rm -rf /userdata/tailscale
mkdir -p /userdata/tailscale
mv tailscale tailscaled /userdata/tailscale/

echo "Cleaning up temporary files..."
cd /userdata
rm -rf /userdata/temp

# --- 4. Configure Tailscale Service for Batocera ---
echo "Configuring Tailscale service file..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/tailscale
#!/bin/bash
if [[ "$1" != "start" ]]; then
  exit 0
fi
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Default interface $INTERFACE does not exist." >&2
    exit 1
fi
# Correctly determine the SUBNET CIDR, not the host CIDR
SUBNET_CIDR=$(ip -o -4 route show dev "$INTERFACE" | awk '/src/ {print $1}' | head -n 1)
if [ -z "$SUBNET_CIDR" ]; then
    echo "Error: Could not determine subnet for interface $INTERFACE." >&2
    exit 1
fi
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &
sleep 2
/userdata/tailscale/tailscale up --advertise-routes=$SUBNET_CIDR --snat-subnet-routes=false --accept-routes
EOF

# ---
