# TechSecure VPN Infrastructure

> **Enterprise-grade remote access architecture** — Active Directory, OpenVPN with PKI, LDAP group-based authorization, 2FA (TOTP), and RADIUS AAA, deployed on a virtualized lab environment.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Stack](#stack)
- [Project Structure](#project-structure)
- [Deployment Guide](#deployment-guide)
  - [1. Network Setup](#1-network-setup)
  - [2. Active Directory & DNS](#2-active-directory--dns)
  - [3. GPO Security Policies](#3-gpo-security-policies)
  - [4. OpenVPN Server (PKI)](#4-openvpn-server-pki)
  - [5. Client Configuration](#5-client-configuration)
  - [6. LDAP Authorization (Group-based Access)](#6-ldap-authorization-group-based-access)
  - [7. RADIUS AAA](#7-radius-aaa)
- [Security Features](#security-features)
- [Validation & Testing](#validation--testing)
- [Screenshots](#screenshots)

---

## Overview

This project implements a **secure remote access infrastructure** for an enterprise environment. The goal is to centralize identity management in Active Directory and enforce that all remote connections transit exclusively through an OpenVPN tunnel authenticated against the directory.

**Key security properties enforced:**

- Remote access is **only possible through the VPN** — direct LAN connections from external hosts are blocked at the firewall level.
- VPN access is **restricted to members of the `Techniciens_VPN` AD group** — certificate possession alone is insufficient.
- All authentication events are **logged and auditable** via Windows Event Log (ID 4625/4624) and OpenVPN journal.
- Session security is enforced via **GPO** (password complexity, account lockout, screen lock).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        LAN: 192.168.10.0/24                     │
│                                                                 │
│   ┌──────────────────┐          ┌──────────────────────────┐   │
│   │  DC01            │          │  VPN01                   │   │
│   │  Windows Server  │◄─────────│  Debian 12               │   │
│   │  2022            │  LDAP    │                          │   │
│   │  192.168.10.10   │  :389    │  LAN: 192.168.10.11      │   │
│   │                  │          │  NAT: DHCP (internet)    │   │
│   │  • AD DS         │          │                          │   │
│   │  • DNS           │          │  • OpenVPN               │   │
│   │  • GPO           │          │  • easy-rsa (CA)         │   │
│   │  • RADIUS relay  │          │  • FreeRADIUS            │   │
│   └──────────────────┘          └──────────┬───────────────┘   │
│                                            │ UDP 1194           │
└────────────────────────────────────────────┼────────────────────┘
                                             │
                                  ┌──────────▼──────────┐
                                  │  CLIENT01            │
                                  │  Windows 11          │
                                  │  192.168.10.20 (LAN) │
                                  │  10.8.0.6 (VPN tun)  │
                                  │                      │
                                  │  • OpenVPN Connect   │
                                  │  • Domain joined     │
                                  └─────────────────────┘

VPN Subnet: 10.8.0.0/24
```

### Authentication Flow

```
Client ──[cert + AD password]──► OpenVPN
                                    │
                            ┌───────▼────────┐
                            │  PAM / RADIUS  │
                            └───────┬────────┘
                                    │
                            ┌───────▼────────┐
                            │  FreeRADIUS    │
                            └───────┬────────┘
                                    │  LDAP :389
                            ┌───────▼────────┐
                            │  Active Dir.   │
                            │  Group check:  │
                            │  Techniciens_  │
                            │  VPN           │
                            └───────┬────────┘
                                    │
                             ✔ ACCEPT / ✘ DENY
```

---

## Stack

| Component | Technology | Role |
|---|---|---|
| Domain Controller | Windows Server 2022 | AD DS, DNS, GPO |
| VPN Gateway | Debian 12 + OpenVPN | TLS tunnel, routing |
| Certificate Authority | easy-rsa 3.x | PKI (CA, server, client certs) |
| Authorization | openvpn-auth-ldap | Group-based AD filtering |
| AAA Server | FreeRADIUS 3.x | RADIUS relay to AD |
| 2FA (tested) | libpam-google-authenticator | TOTP via Google Authenticator |
| Client | Windows 11 + OpenVPN Connect | Remote workstation |
| Hypervisor | VMware Workstation | Lab environment |

---

## Project Structure

```
techsecure-vpn-infra/
│
├── README.md
├── config/
│   ├── openvpn/
│   │   ├── server.conf          # OpenVPN server configuration
│   │   └── client.ovpn          # Client profile template
│   ├── active-directory/
│   │   └── ou-structure.md      # OU/group design documentation
│   ├── gpo/
│   │   └── policies.md          # GPO settings reference
│   └── pki/
│       └── pki-commands.md      # easy-rsa PKI setup commands
│
├── scripts/
│   ├── setup-pki.sh             # Automates PKI initialization
│   ├── add-vpn-user.sh          # Creates a new VPN-enabled user
│   └── revoke-user.sh           # Revokes a user's VPN access
│
├── docs/
│   ├── architecture/
│   │   └── network-diagram.md
│   ├── DEPLOYMENT.md            # Step-by-step deployment guide
│   ├── SECURITY.md              # Security model & threat analysis
│   └── screenshots/             # Proof-of-work captures
│
└── .gitignore
```

---

## Deployment Guide

Full step-by-step instructions: **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**

### 1. Network Setup

| Host | OS | IP | Role |
|---|---|---|---|
| DC01 | Windows Server 2022 | 192.168.10.10 | Domain Controller, DNS |
| VPN01 | Debian 12 | 192.168.10.11 (LAN) + NAT | VPN Gateway, CA, RADIUS |
| CLIENT01 | Windows 11 | 192.168.10.20 | Domain workstation |

All machines are placed on the same isolated LAN segment (`techsecure`). VPN01 has a second NIC in NAT mode for internet access (package downloads).

DC01 uses VPN01 (`192.168.10.11`) as its **default gateway** so that return traffic destined for VPN clients (`10.8.0.x`) is correctly routed back through the Debian machine.

### 2. Active Directory & DNS

Domain: `techsecure.local` | NetBIOS: `TECHSECURE`

**OU Structure (`TechSecure_Corp`):**
```
TechSecure_Corp/
├── Direction
├── RH
├── Technique        ← hamdanimed lives here
└── Comptabilite
```

**Security Groups:**
| Group | Purpose |
|---|---|
| `Techniciens_VPN` | **Required** for VPN access — enforced at LDAP level |
| `Admins_Domaine` | System administrators |
| `Employes_Internes` | Standard on-site employees |

### 3. GPO Security Policies

See **[config/gpo/policies.md](config/gpo/policies.md)** for full details.

| Policy | Value |
|---|---|
| Password minimum length | 14 characters |
| Complexity requirements | Enabled (upper, lower, digit) |
| Password history | 5 passwords remembered |
| Max password age | 90 days |
| Account lockout threshold | 5 failed attempts |
| Lockout duration | 15 minutes |
| Idle screen lock | 10 minutes (600s) |
| Audit: logon success/failure | Enabled → Event ID 4624 / 4625 |

### 4. OpenVPN Server (PKI)

```bash
# Install packages
sudo apt install openvpn easy-rsa -y

# Initialize PKI
cd /etc/openvpn/easy-rsa
sudo ./easyrsa init-pki
sudo ./easyrsa build-ca nopass        # CN: TechSecure-CA

# Generate server credentials
sudo ./easyrsa gen-req server nopass
sudo ./easyrsa sign-req server server
sudo ./easyrsa gen-dh

# Generate a client certificate
sudo ./easyrsa gen-req <username> nopass
sudo ./easyrsa sign-req client <username>

# Start the service
sudo systemctl enable --now openvpn@server
```

See **[config/pki/pki-commands.md](config/pki/pki-commands.md)** for the full reference.

### 5. Client Configuration

The client `.ovpn` profile (template in `config/openvpn/client.ovpn`) references:
- `ca.crt` — the CA certificate
- `<username>.crt` — the client certificate
- `<username>.key` — the client private key

Files are transferred from VPN01 using a temporary Python HTTP server:
```bash
# On VPN01
cd /etc/openvpn/client/keys
python3 -m http.server 8000
```

### 6. LDAP Authorization (Group-based Access)

Install and configure `openvpn-auth-ldap`:

```bash
sudo apt install openvpn-auth-ldap -y
```

Config file: `/etc/openvpn/auth/ldap.conf`

```xml
<LDAP>
    URL           ldap://192.168.10.10
    Timeout       15
    TLSEnable     no
    BindDN        "CN=Administrateur,CN=Users,DC=techsecure,DC=local"
    Password      "<service-account-password>"
    FollowReferrals yes
</LDAP>

<Authorization>
    BaseDN        "DC=techsecure,DC=local"
    SearchFilter  "(&(objectClass=user)(sAMAccountName=%u))"
    RequireGroup  true

    <Group>
        BaseDN          "OU=TechSecure-Corp,DC=techsecure,DC=local"
        SearchFilter    "(cn=Techniciens_VPN)"
        MemberAttribute "member"
    </Group>
</Authorization>
```

Removing a user from `Techniciens_VPN` in Active Directory **immediately revokes** their VPN access — no server-side changes required.

### 7. RADIUS AAA

```bash
sudo apt install freeradius freeradius-utils freeradius-ldap libpam-radius-auth -y
```

Authentication chain: `OpenVPN → PAM → RADIUS → FreeRADIUS → Active Directory`

See **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md#radius-aaa)** for detailed configuration.

---

## Security Features

| Feature | Implementation | Status |
|---|---|---|
| Mutual TLS authentication | X.509 certificates via easy-rsa CA | ✅ |
| AD group-based VPN authorization | openvpn-auth-ldap + `Techniciens_VPN` group | ✅ |
| VPN-exclusive remote access | Windows Firewall rule blocking direct LAN access from remote hosts | ✅ |
| Password policy enforcement | Default Domain Policy GPO | ✅ |
| Account lockout (brute-force protection) | 5 attempts → 15 min lockout | ✅ |
| Session auto-lock | GPO screensaver with password (10 min) | ✅ |
| Authentication audit trail | Windows Security Log (4624/4625) + OpenVPN journal | ✅ |
| RADIUS AAA | FreeRADIUS → AD relay | ✅ |
| TOTP 2FA (experimental) | libpam-google-authenticator | ⚠️ Tested, stability issues in PAM chain |

---

## Validation & Testing

### Positive Tests (Expected: ALLOW)

```
[✔] Client ping DC01 (192.168.10.10) through VPN tunnel — TTL=127
[✔] whoami returns techsecure\hamdanimed after domain join
[✔] OpenVPN logs: CN=hamdanimed certificate verified, IP 10.8.0.6 assigned
[✔] LDAP query confirms memberOf: CN=Techniciens_VPN
[✔] FreeRADIUS + AD authentication chain validated with radtest
```

### Negative Tests (Expected: DENY)

```
[✔] Password "123" rejected by AD on user creation (GPO complexity)
[✔] Account locked after 5 failed logins — Event ID 4625 recorded
[✔] Direct ping to DC01 (bypassing VPN) blocked by Windows Firewall rule
[✔] User "madara" (valid cert, NOT in Techniciens_VPN) → AUTH_FAILED
     Phase 1 (TLS cert): PASSED
     Phase 2 (LDAP group check): FAILED → connection rejected
```

---

## Screenshots

Visual proof-of-work captures are organized in [`docs/screenshots/`](docs/screenshots/).

| Area | Key Screenshots |
|---|---|
| Network | VM NIC config, static IP setup, ping connectivity tests |
| Active Directory | OU structure, user creation, domain join, `whoami` output |
| GPO | Password policy, lockout settings, screensaver GPO, Event ID 4625 |
| PKI / OpenVPN | easy-rsa init, CA build, server/client cert signing, `systemctl status` |
| VPN Client | OpenVPN Connect "Securely Connected", IP 10.8.0.6, ping through tunnel |
| LDAP Auth | ldapsearch output (memberOf), access granted/denied logs |
| RADIUS | FreeRADIUS config, PAM chain, successful auth log |

---

## .gitignore

See [`.gitignore`](.gitignore) — private keys (`*.key`), PKI secrets, and any credential files are excluded from version control.

