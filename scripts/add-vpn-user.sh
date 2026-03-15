#!/usr/bin/env bash
# =============================================================
# add-vpn-user.sh — Provision a new VPN client certificate
#
# Usage: sudo ./add-vpn-user.sh <username>
#
# Prerequisites:
#   - PKI already initialized (run setup-pki.sh first)
#   - User exists in Active Directory and is a member of
#     the Techniciens_VPN group
# =============================================================

set -euo pipefail

EASYRSA_DIR="/etc/openvpn/easy-rsa"
CLIENT_KEYS_DIR="/etc/openvpn/client/keys"
VPN_SERVER="192.168.10.11"
VPN_PORT="1194"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"

echo "[*] Generating client certificate for: $USERNAME"
cd "$EASYRSA_DIR"
./easyrsa --batch gen-req "$USERNAME" nopass
./easyrsa --batch sign-req client "$USERNAME"

echo "[*] Copying client files to $CLIENT_KEYS_DIR..."
mkdir -p "$CLIENT_KEYS_DIR"
cp pki/ca.crt "$CLIENT_KEYS_DIR/"
cp "pki/issued/${USERNAME}.crt" "$CLIENT_KEYS_DIR/"
cp "pki/private/${USERNAME}.key" "$CLIENT_KEYS_DIR/"

echo "[*] Generating .ovpn profile..."
cat > "${CLIENT_KEYS_DIR}/${USERNAME}.ovpn" << EOF
client
dev tun
proto udp
remote ${VPN_SERVER} ${VPN_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
auth-user-pass
ca   ca.crt
cert ${USERNAME}.crt
key  ${USERNAME}.key
EOF

echo ""
echo "[✔] Done. Files ready in: $CLIENT_KEYS_DIR"
echo "    Transfer to client:"
echo "      ca.crt, ${USERNAME}.crt, ${USERNAME}.key, ${USERNAME}.ovpn"
echo ""
echo "    Quick transfer (temporary HTTP server):"
echo "      cd $CLIENT_KEYS_DIR && python3 -m http.server 8000"
