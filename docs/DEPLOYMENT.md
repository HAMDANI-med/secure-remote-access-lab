# Deployment Guide

Complete step-by-step instructions for reproducing the TechSecure VPN infrastructure.

---

## Prerequisites

- VMware Workstation (or equivalent hypervisor)
- ISO images: Windows Server 2022, Debian 12, Windows 11
- Minimum resources: 8 GB RAM, 4 CPU cores, 350 GB disk

---

## Step 1 — Network Topology

Create a **LAN Segment** named `techsecure` in VMware. All VMs except VPN01's NAT adapter will use this segment.

| VM | vNIC 1 | vNIC 2 |
|---|---|---|
| DC01 | LAN Segment: `techsecure` | — |
| VPN01 | LAN Segment: `techsecure` | NAT (internet) |
| CLIENT01 | LAN Segment: `techsecure` | — |

---

## Step 2 — DC01: Static IP

In **Network and Sharing Center → Adapter Properties → IPv4**:

```
IP Address:  192.168.10.10
Subnet Mask: 255.255.255.0
Gateway:     192.168.10.11   ← VPN01 as gateway (added later)
DNS:         127.0.0.1
```

---

## Step 3 — VPN01: Dual NIC Configuration

Edit `/etc/network/interfaces`:

```
# NIC 1 — Internet (NAT)
auto ens33
iface ens33 inet dhcp

# NIC 2 — Internal LAN
auto ens36
iface ens36 inet static
    address 192.168.10.11
    netmask 255.255.255.0
```

Apply:
```bash
sudo systemctl restart networking
```

Verify:
```bash
ping -c 3 google.com        # NAT connectivity
ping -c 3 192.168.10.10     # LAN connectivity to DC01
```

---

## Step 4 — Active Directory Deployment

### 4.1 Install AD DS and DNS roles

Open **Server Manager → Add Roles and Features** and select:
- `Active Directory Domain Services`
- `DNS Server`

### 4.2 Promote DC01 as Domain Controller

Run the AD DS Configuration Wizard:
- Operation: **Add a new forest**
- Root domain name: `techsecure.local`
- NetBIOS name: `TECHSECURE`
- Set the DSRM password

Reboot when prompted. Log in as `TECHSECURE\Administrateur`.

### 4.3 Create OU Structure

In **Active Directory Users and Computers (dsa.msc)**:

```
techsecure.local
└── TechSecure-Corp  (OU)
    ├── Direction    (OU)
    ├── RH           (OU)
    ├── Technique    (OU)
    └── Comptabilite (OU)
```

### 4.4 Create Security Groups

Create the following **Global Security** groups at the root of `techsecure.local`:

| Group Name | Description |
|---|---|
| `Techniciens_VPN` | Grants VPN access (enforced by LDAP) |
| `Admins_Domaine` | Domain administrators |
| `Employes_Internes` | On-site standard users |

### 4.5 Create a User

Example: create `hamdanimed` in `TechSecure-Corp/Technique`:
- First name: `hamdani`, Last name: `mohammed`
- UPN: `hamdanimed@techsecure.local`
- Add to group `Techniciens_VPN`

---

## Step 5 — Join CLIENT01 to the Domain

On CLIENT01, configure the NIC:
```
IP: 192.168.10.20
Subnet: 255.255.255.0
DNS: 192.168.10.10    ← points to DC01
```

Then: **System Properties → Computer Name → Change → Domain: `techsecure.local`**

Authenticate with domain admin credentials. Reboot.

Verify:
```cmd
whoami
# Expected: techsecure\hamdanimed
```

---

## Step 6 — GPO: Security Policies

Open **Group Policy Management (gpmc.msc)** on DC01.

### Password & Lockout Policy (Default Domain Policy)

Navigate to: `Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies`

| Setting | Value |
|---|---|
| Minimum password length | 14 |
| Password must meet complexity requirements | Enabled |
| Enforce password history | 5 passwords |
| Maximum password age | 90 days |
| Account lockout threshold | 5 invalid attempts |
| Account lockout duration | 15 minutes |
| Reset lockout counter after | 15 minutes |

### Screen Lock (User Configuration)

Navigate to: `User Configuration → Policies → Administrative Templates → Control Panel → Personalization`

| Setting | Value |
|---|---|
| Enable screen saver | Enabled |
| Password protect the screen saver | Enabled |
| Screen saver timeout | 600 seconds |

### Audit Policy

Navigate to: `Computer Configuration → Policies → Windows Settings → Security Settings → Advanced Audit Policy → Logon/Logoff`

| Setting | Value |
|---|---|
| Audit Logon | Success and Failure |

Failed logins generate **Event ID 4625** in the Security log (`eventvwr.msc`).

---

## Step 7 — OpenVPN Server & PKI

### 7.1 Install packages

```bash
sudo apt install openvpn easy-rsa -y
```

### 7.2 Initialize the PKI

```bash
sudo mkdir -p /etc/openvpn/easy-rsa
sudo ln -s /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

sudo ./easyrsa init-pki
```

### 7.3 Build the Certificate Authority

```bash
sudo ./easyrsa build-ca nopass
# Common Name: TechSecure-CA
```

### 7.4 Generate server credentials

```bash
sudo ./easyrsa gen-req server nopass
sudo ./easyrsa sign-req server server
sudo ./easyrsa gen-dh
```

### 7.5 Generate a client certificate

```bash
sudo ./easyrsa gen-req <username> nopass
sudo ./easyrsa sign-req client <username>
```

### 7.6 Copy files to OpenVPN directories

```bash
sudo cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/
sudo mkdir -p /etc/openvpn/client/keys
sudo cp pki/ca.crt /etc/openvpn/client/keys/
sudo cp pki/issued/<username>.crt /etc/openvpn/client/keys/
sudo cp pki/private/<username>.key /etc/openvpn/client/keys/
```

### 7.7 Server configuration

Create `/etc/openvpn/server.conf` — see [`config/openvpn/server.conf`](../config/openvpn/server.conf).

### 7.8 Enable IP forwarding and start the service

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl --system

sudo systemctl enable --now openvpn@server
sudo systemctl status openvpn@server
```

---

## Step 8 — Client Setup

### 8.1 Transfer files from VPN01

On VPN01:
```bash
cd /etc/openvpn/client/keys
python3 -m http.server 8000
```

On CLIENT01, open `http://192.168.10.11:8000` and download:
- `ca.crt`
- `<username>.crt`
- `<username>.key`
- `openvpn-connect-*.msi`

### 8.2 Create the client profile

See template: [`config/openvpn/client.ovpn`](../config/openvpn/client.ovpn)

Key directives:
```
remote 192.168.10.11 1194
ca     ca.crt
cert   <username>.crt
key    <username>.key
```

### 8.3 Import and connect

Import `techsecure.ovpn` into OpenVPN Connect. The client will receive IP `10.8.0.x` from the VPN subnet.

---

## Step 9 — DC01 Routing (Default Gateway)

Set VPN01 as the default gateway on DC01 so it can route replies back to VPN clients:

**NIC Properties → IPv4 → Default Gateway: `192.168.10.11`**

---

## Step 10 — Firewall Rule (VPN-only enforcement)

On DC01, open **Windows Defender Firewall with Advanced Security (`wf.msc`)**:

Create an **inbound rule**:
- Action: Block
- Protocol: ICMPv4
- Scope → Remote IP: `192.168.10.20` (CLIENT01's physical IP)

This forces CLIENT01 to use the VPN tunnel (IP `10.8.0.x`) to reach DC01. Direct LAN access is rejected.

---

## Step 11 — LDAP Authorization

### 11.1 Install

```bash
sudo apt install openvpn-auth-ldap -y
```

### 11.2 Configure

Create `/etc/openvpn/auth/ldap.conf` — see [`config/openvpn/server.conf`](../config/openvpn/server.conf) comments and the LDAP section.

### 11.3 Validate LDAP connectivity

```bash
# Check port
nc -zv 192.168.10.10 389

# Test directory read
ldapsearch -x -H ldap://192.168.10.10 \
  -D "CN=Administrateur,CN=Users,DC=techsecure,DC=local" \
  -W \
  -b "DC=techsecure,DC=local" \
  "(sAMAccountName=hamdanimed)"
```

Expected output includes `memberOf: CN=Techniciens_VPN,OU=TechSecure-Corp,...`

---

## RADIUS AAA

### Installation

```bash
sudo apt install freeradius freeradius-utils freeradius-ldap libpam-radius-auth -y
```

### FreeRADIUS → Active Directory

Edit `/etc/freeradius/3.0/mods-available/ldap`:
```
server = '192.168.10.10'
identity = 'CN=Administrateur,CN=Users,DC=techsecure,DC=local'
password = '<password>'
base_dn = 'DC=techsecure,DC=local'
```

Enable module and restart:
```bash
sudo ln -s /etc/freeradius/3.0/mods-available/ldap /etc/freeradius/3.0/mods-enabled/
sudo systemctl restart freeradius
```

### OpenVPN → PAM → RADIUS chain

`/etc/pam_radius_auth.conf`:
```
127.0.0.1   testing123   30
```

`/etc/pam.d/openvpn`:
```
auth     sufficient   pam_radius_auth.so
account  required     pam_permit.so
```

`server.conf` (add):
```
plugin /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
```

### Full authentication chain

```
Client credentials (AD password)
  → OpenVPN
    → PAM (pam_radius_auth.so)
      → FreeRADIUS (:1812)
        → LDAP module → Active Directory
          ✔ or ✘
```

---

## Monitoring

### OpenVPN live log

```bash
sudo journalctl -u openvpn@server -f
```

Key events to watch:
- `VERIFY OK` — certificate validated
- `Peer Connection Initiated` — tunnel established
- `AUTH_FAILED` — authentication or group check failed

### Active Directory audit

Open **Event Viewer → Windows Logs → Security** on DC01:
- **4624** — Successful logon
- **4625** — Failed logon (wrong password, locked account)
