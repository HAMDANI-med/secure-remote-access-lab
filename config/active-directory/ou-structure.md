# Active Directory Structure

Domain: `techsecure.local`  
NetBIOS: `TECHSECURE`  
Functional level: Windows Server 2016

---

## OU Hierarchy

```
techsecure.local
└── TechSecure-Corp          (Organizational Unit)
    ├── Direction            (OU — executive staff)
    ├── RH                   (OU — HR department)
    ├── Technique            (OU — technical team, VPN users)
    └── Comptabilite         (OU — accounting)
```

All OUs are children of the root container `TechSecure-Corp`.

---

## Security Groups

| Group Name | Type | Scope | Purpose |
|---|---|---|---|
| `Techniciens_VPN` | Security | Global | **VPN access** — enforced by LDAP plugin. Only members can authenticate through OpenVPN. |
| `Admins_Domaine` | Security | Global | Domain administrators (system management) |
| `Employes_Internes` | Security | Global | Standard on-site users (no VPN access) |

---

## Test Accounts

| Username | UPN | OU | Groups | Access |
|---|---|---|---|---|
| `hamdanimed` | hamdanimed@techsecure.local | Technique | `Techniciens_VPN` | ✅ VPN allowed |
| `madara` | madara@techsecure.local | Comptabilite | *(none)* | ❌ VPN denied |

`madara` was used in the **negative security test** (section 12 of the report): a valid X.509 certificate was issued but LDAP group check correctly rejected the connection.

---

## Adding a New VPN User

1. Create the user account in the appropriate OU.
2. Add the user to the `Techniciens_VPN` group.
3. Generate a client certificate via easy-rsa (see [pki-commands.md](../pki/pki-commands.md)).
4. Transfer `ca.crt`, `<username>.crt`, `<username>.key`, and the `.ovpn` profile to the user.

## Revoking VPN Access

1. Remove the user from `Techniciens_VPN` in Active Directory.  
   → Access is denied **immediately** on the next connection attempt (no server restart needed).
2. Optionally revoke the certificate via `./easyrsa revoke <username>` and regenerate the CRL.
