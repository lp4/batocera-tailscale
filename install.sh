#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Smarter Auth Key Logic ---
# Check if an auth key was passed as the first argument
if [ -n "$1" ]; then
  TAILSCALE_AUTH_KEY="$1"
  echo "Using auth key provided as a command-line argument."
# Check if standard input is a terminal (i.e., script is run interactively)
elif [ -t 0 ]; then
  read -p "Please enter your Tailscale auth key: " TAILSCALE_AUTH_KEY
# If not interactive and no argument was given, fail with instructions
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

# ... the rest of the script is the same ...

echo "Running Tailscale install script..."

# --- 1. Determine System Architecture ---
echo "Detecting system architecture..."
case "$(uname -m)" in
    x86_64)   arch="amd64" ;;
    aarch64)  arch="arm64" ;;
    armv7l)   arch="arm" ;;
    riscv64)  arch="riscv64" ;;
    i386|i686|x86) arch="386" ;;
    *)
      echo "Error: Unsupported architecture '$(uname -m)'." >&2
      exit 1
      ;;
esac
echo "Architecture found: $arch"

# --- 2. Stop and Disable Existing Tailscale Service ---
echo "Stopping and disabling any existing Tailscale service..."
batocera-services stop tailscale || true
batocera-services disable tailscale || true

# --- 3. Download and Install Tailscale ---
echo "Creating temporary directory for download..."
rm -rf /userdata/temp
mkdir -p /userdata/temp
cd /userdata/temp

echo "Downloading Tailscale v1.88.3 for your system..."
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
CIDDR=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}')
if [ -z "$CIDDR" ]; then
    echo "Error: No IP address found for interface $INTERFACE." >&2
    exit 1
fi
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &
sleep 2
/userdata/tailscale/tailscale up --advertise-routes=$CIDDR --snat-subnet-routes=false --accept-routes
EOF

# --- 5. Configure System for IP Forwarding ---
echo "Enabling IP forwarding..."
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun
cat <<EOL > "/etc/sysctl.conf"
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL
sysctl -p /etc/sysctl.conf

# --- 6. Initial Authentication and Subnet Setup ---
echo "Starting Tailscale daemon for initial authentication..."
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &
sleep 2
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
CIDDR=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}')
echo "Authenticating with Tailscale and advertising subnet route: $CIDDR"
/userdata/tailscale/tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --advertise-routes=$CIDDR --snat-subnet-routes=false --accept-routes

# --- 7. Apply Network Optimizations (if needed) ---
NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
if dmesg | grep -q "UDP GRO forwarding is suboptimally configured"; then
    echo "Applying UDP GRO forwarding fix on $NETDEV..."
    ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off
    ethtool -K $NETDEV gro off
fi

# --- 8. Finalize and Start Service ---
echo "Saving system configuration overlay..."
batocera-save-overlay
echo "Enabling and starting Tailscale service..."
batocera-services enable tailscale
batocera-services start tailscale
batocera-save-overlay

echo "--------------------------------------------------"
echo "✅ Tailscale installation and configuration complete!"
echo "--------------------------------------------------"
echo "Showing current network interfaces..."
sleep 2
ip a
echo
echo "IMPORTANT: Go to your Tailscale Admin Console."
echo "1. Find this new machine and approve its subnet route ($CIDDR)."
echo "2. It is also recommended to 'Disable key expiry' for this machine."
echo
