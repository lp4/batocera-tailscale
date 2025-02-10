#!/bin/bash
echo "Getting Details Please Wait......."
sleep 2
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
echo "INTERFACE = $INTERFACE"
echo "LOCAL IP = $IP"
echo "NETWORK = $NETWORK"
echo "CIDR = $CIDR"
