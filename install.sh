#!/bin/sh

# This script will install the latest version of Tailscale to /userdata/tailscale
# It automatically detects the system architecture.

# Exit immediately if any command fails
set -e

echo "--- Batocera Tailscale Installer ---"

# 1. Detect system architecture
echo "--> Detecting system architecture..."
case $(uname -m) in
    x86_64)
        TS_ARCH="amd64"
        ;;
    aarch64)
        TS_ARCH="arm64"
        ;;
    armv7l)
        TS_ARCH="arm"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac
echo "    Architecture detected: ${TS_ARCH}"

# 2. Find the latest version of Tailscale from the GitHub API
echo "--> Finding latest Tailscale version..."
TS_VER=$(curl -s "https://api.github.com/repos/tailscale/tailscale/releases/latest" | grep -oP '"tag_name": "\Kv[^"]+' | sed 's/v//')

if [ -z "$TS_VER" ]; then
    echo "ERROR: Could not determine the latest Tailscale version. Check network connection."
    exit 1
fi
echo "    Latest version is: ${TS_VER}"

# 3. Set up the installation directory
INSTALL_DIR="/userdata/tailscale"
echo "--> Preparing installation directory: ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

# 4. Download and extract the binaries
DOWNLOAD_URL="https://pkgs.tailscale.com/stable/tailscale_${TS_VER}_${TS_ARCH}.tgz"
echo "--> Downloading from ${DOWNLOAD_URL}"
wget "${DOWNLOAD_URL}" -O /tmp/tailscale.tgz

echo "--> Extracting files..."
# The --strip-components=1 flag removes the top-level folder from the tarball
tar xzf /tmp/tailscale.tgz --strip-components=1 -C "${INSTALL_DIR}"

# 5. Clean up the downloaded file
echo "--> Cleaning up..."
rm /tmp/tailscale.tgz

echo ""
echo "✅ Success! Tailscale has been installed to ${INSTALL_DIR}"
echo ""
echo "----------------------------------------------------------"
echo "IMPORTANT: Remember to configure your startup scripts"
echo "(e.g., /userdata/system/custom.sh and /etc/batocera-boot.conf)"
echo "to run Tailscale at boot, then reboot your system."
echo "----------------------------------------------------------"
