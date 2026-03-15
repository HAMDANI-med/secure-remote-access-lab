#!/usr/bin/env bash
# =============================================================
# setup-pki.sh — Initialize the TechSecure PKI
# Run on VPN01 (Debian 12) as root or with sudo.
# =============================================================

set -euo pipefail

EASYRSA_DIR="/etc/openvpn/easy-rsa"
CA_CN="TechSecure-CA"

echo "[*] Installing packages..."
apt-get install -y openvpn easy-rsa

echo "[*] Setting up easy-rsa directory..."
mkdir -p "$EASYRSA_DIR"
ln -sf /usr/share/easy-rsa/* "$EASYRSA_DIR/"
cd "$EASYRSA_DIR"

echo "[*] Initializing PKI..."
./easyrsa init-pki

echo "[*] Building Certificate Authority (CN: $CA_CN)..."
./easyrsa --batch --req-cn="$CA_CN" build-ca nopass

echo "[*] Generating server certificate..."
./easyrsa --batch gen-req server nopass
./easyrsa --batch sign-req server server

echo "[*] Generating Diffie-Hellman parameters (2048 bit)..."
./easyrsa gen-dh

echo "[*] Copying files to /etc/openvpn/..."
cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/

echo ""
echo "[✔] PKI setup complete."
echo "    Next: run ./add-vpn-user.sh <username> to provision a client certificate."
