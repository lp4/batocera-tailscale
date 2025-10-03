#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Prompt for Tailscale Auth Key ---
# This logic allows the key to be passed as an argument or entered interactively.
if [ -n "$1" ]; then
  # Use the first command-line argument as the key
  TAILSCALE_AUTH_KEY="$1"
  echo "Using auth key provided as a command-line argument."
else
  # Otherwise, prompt the user interactively, reading directly from the terminal
  read -p "Please enter your Tailscale auth key: " TAILSCALE_AUTH_KEY < /dev/tty
fi

if [[ -z "$TAILSCALE_AUTH_KEY" ]]; then
    echo "Error: Auth key was not provided. Exiting." >&2
    exit 1
fi

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
# The service file calculates the subnet route dynamically on each start
cat << 'EOF' > /userdata/system/services/tailscale
#!/bin/bash

# Only run on "start"
if [[ "$1" != "start" ]]; then
  exit 0
fi

# Dynamically find the default interface and its CIDR
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

# Start the daemon and bring the connection up
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &
sleep 2 # Give daemon time to start
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
sleep 2 # Give the daemon a moment to start

# Calculate CIDR for the initial "up" command
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
batocera-save-overlay # Save again to ensure the service is enabled on boot

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
