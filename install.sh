#!/bin/bash

# This script installs the latest Tailscale and correctly overrides the
# default Batocera service, allowing 'batocera-services start tailscale' to work.

set -e

echo "--- Batocera Tailscale Integration Script ---"

# 1. Stop and disable the old, built-in service to prevent conflicts
echo "--> Stopping and disabling the default Tailscale service..."
batocera-services stop tailscale
batocera-services disable tailscale

# 2. Detect system architecture
echo "--> Detecting system architecture..."
case $(uname -m) in
    x86_64 | amd64) TS_ARCH="amd64" ;;
    aarch64) TS_ARCH="arm64" ;;
    armv7l | arm) TS_ARCH="arm" ;;
    i386 | i686) TS_ARCH="386" ;;
    riscv64) TS_ARCH="riscv64" ;;
    *)
        echo "ERROR: Unsupported architecture: $(uname -m)"; exit 1 ;;
esac
echo "    Architecture detected: ${TS_ARCH}"

# 3. Find and download the latest version
echo "--> Finding and downloading the latest Tailscale version..."
TS_VER=$(curl -s "https://api.github.com/repos/tailscale/tailscale/releases/latest" | grep -oP '"tag_name": "\Kv[^"]+' | sed 's/v//')
if [ -z "$TS_VER" ]; then
    echo "ERROR: Could not determine the latest Tailscale version."; exit 1;
fi
echo "    Latest version is: ${TS_VER}"
INSTALL_DIR="/userdata/tailscale"
mkdir -p "${INSTALL_DIR}"
DOWNLOAD_URL="https://pkgs.tailscale.com/stable/tailscale_${TS_VER}_${TS_ARCH}.tgz"
wget "${DOWNLOAD_URL}" -O /tmp/tailscale.tgz
tar xzf /tmp/tailscale.tgz --strip-components=1 -C "${INSTALL_DIR}"
rm /tmp/tailscale.tgz
echo "    Installation complete."

# 4. Create the custom service file that batocera-services will use
echo "--> Creating custom service file..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/tailscale
#!/bin/sh
# This is the custom service file for the new Tailscale installation.
# It will be used by 'batocera-services start/stop'.

# The daemon's state file location
STATE_FILE="/userdata/tailscale/state"

case "$1" in
    start)
        # Start the new tailscaled daemon in the background
        /userdata/tailscale/tailscaled --state=${STATE_FILE} &
        ;;
    stop)
        # Stop the daemon
        killall tailscaled
        ;;
    *)
        exit 1
        ;;
esac
exit 0
EOF
chmod +x /userdata/system/services/tailscale
echo "    Service file created at /userdata/system/services/tailscale"

# 5. Create a helper script to connect and advertise routes
echo "--> Creating connection helper script..."
cat << 'EOF' > /userdata/tailscale/connect.sh
#!/bin/bash
# This script brings the Tailscale connection up and advertises the local subnet.

# Calculate local subnet
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
CIDDR=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}')
IP=$(echo "$CIDDR" | cut -d'/' -f1)
PREFIX=$(echo "$CIDDR" | cut -d'/' -f2)
IFS=. read -r o1 o2 o3 o4 <<< "$IP"
MASK=$(( 0xFFFFFFFF << (32 - PREFIX) ))
IFS=. read -r m1 m2 m3 m4 <<< "$(printf "%d.%d.%d.%d" $(( (MASK >> 24) & 0xFF )) $(( (MASK >> 16) & 0xFF )) $(( (MASK >> 8) & 0xFF )) $(( MASK & 0xFF )))"
NETWORK=$(printf "%d.%d.%d.%d" $(( o1 & m1 )) $(( o2 & m2 )) $(( o3 & m3 )) $(( o4 & m4 )))
SUBNET="${NETWORK}/${PREFIX}"

# Bring the connection up with the calculated subnet route
/userdata/tailscale/tailscale up --advertise-routes=${SUBNET} --snat-subnet-routes=false --accept-routes
EOF
chmod +x /userdata/tailscale/connect.sh
echo "    Connection script created at /userdata/tailscale/connect.sh"


# 6. Configure IP forwarding and save overlay
echo "--> Configuring IP forwarding..."
cat <<EOL > "/etc/sysctl.conf"
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL
sysctl -p /etc/sysctl.conf
batocera-save-overlay

echo ""
echo "✅ --- INSTALLATION COMPLETE ---"
echo "A REBOOT IS REQUIRED for the new service to be recognized."
echo "Please reboot your Batocera machine now."
