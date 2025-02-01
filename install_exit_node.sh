#!/bin/bash

arch=""
echo "Running install script"
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
esac

# Creating temp files
echo "Creating temp files..."
rm -rf /userdata/temp
mkdir -p /userdata/temp
cd /userdata/temp || exit 1

# Dowload tailscale zip as per architecture
echo "Downloading tailscale for your system........"
wget -q https://pkgs.tailscale.com/stable/tailscale_1.78.1_$arch.tgz

# Exctrating Zip Files
echo "Extracting Files and Creating Tailscale Folders..."
tar -xf tailscale_1.78.1_$arch.tgz
cd tailscale_1.78.1_$arch || exit 1
rm -rf /userdata/tailscale
mkdir /userdata/tailscale
mv systemd /userdata/tailscale/systemd
mv tailscale /userdata/tailscale/tailscale
mv tailscaled /userdata/tailscale/tailscaled
cd /userdata || exit 1
rm -rf /userdata/temp

echo "Configuring Tailscale service..."
mkdir -p /userdata/system/services
rm -rf /userdata/system/services/tailscale
cat << 'EOF' > /userdata/system/services/tailscale
#!/bin/bash
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Interface $INTERFACE does not exist." >&2
    exit 1
fi

CIDDR=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}')

if [ -z "$CIDDR" ]; then
    echo "Error: No IP address found for interface $INTERFACE." >&2
    exit 1
fi

IP=$(echo "$CIDDR" | cut -d'/' -f1)
PREFIX=$(echo "$CIDDR" | cut -d'/' -f2)

MASK=$(( 0xFFFFFFFF << (32 - PREFIX) & 0xFFFFFFFF ))
MASK_OCTETS=$(printf "%d.%d.%d.%d" $(( (MASK >> 24) & 0xFF )) \
                                  $(( (MASK >> 16) & 0xFF )) \
                                  $(( (MASK >> 8) & 0xFF )) \
                                  $(( MASK & 0xFF )))

IFS=. read -r o1 o2 o3 o4 <<< "$IP"
IFS=. read -r m1 m2 m3 m4 <<< "$MASK_OCTETS"
NETWORK=$(printf "%d.%d.%d.%d" $(( o1 & m1 )) \
                              $(( o2 & m2 )) \
                              $(( o3 & m3 )) \
                              $(( o4 & m4 )))

CIDR=$(printf $NETWORK/$PREFIX)

if [[ "$1" != "start" ]]; then
  exit 0
fi
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &/userdata/tailscale/tailscale up --advertise-routes=$CIDR --snat-subnet-routes=false --accept-routes --advertise-exit-node

EOF
echo "Creating tun, forwarding ip and saving batocera-overlay....."
rm -rf /dev/net
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat <<EOL > "/etc/sysctl.conf"
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOL

batocera-save-overlay
sysctl -p /etc/sysctl.conf

# Start Tailscale daemon
/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &/userdata/tailscale/tailscale up

NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
ethtool -K $NETDEV rx-udp-gro-forwarding on rx-gro-list off
ethtool -K $NETDEV gro off


/userdata/tailscale/tailscaled -state /userdata/tailscale/state > /userdata/tailscale/tailscaled.log 2>&1 &/userdata/tailscale/tailscale up

batocera-services enable tailscale
batocera-services start tailscale

