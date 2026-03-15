#!/usr/bin/env bash
# =============================================================
# revoke-user.sh — Revoke a VPN client certificate
#
# Usage: sudo ./revoke-user.sh <username>
#
# This script:
#   1. Revokes the certificate in the PKI
#   2. Regenerates the CRL (Certificate Revocation List)
#   3. Copies the updated CRL to /etc/openvpn/
#   4. Reloads the OpenVPN service
#
# Note: Also remove the user from the Techniciens_VPN AD group
# to block LDAP-based access immediately (no restart needed).
# =============================================================

set -euo pipefail

EASYRSA_DIR="/etc/openvpn/easy-rsa"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"

echo "[*] Revoking certificate for: $USERNAME"
cd "$EASYRSA_DIR"
./easyrsa --batch revoke "$USERNAME"

echo "[*] Regenerating Certificate Revocation List..."
./easyrsa gen-crl

echo "[*] Deploying updated CRL to /etc/openvpn/..."
cp pki/crl.pem /etc/openvpn/

echo "[*] Reloading OpenVPN service..."
systemctl reload openvpn@server

echo ""
echo "[✔] Certificate revoked. $USERNAME can no longer connect."
echo ""
echo "[!] REMINDER: Also remove $USERNAME from the Techniciens_VPN"
echo "    group in Active Directory to block LDAP-based access."
