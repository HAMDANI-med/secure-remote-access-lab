# Security Model

This document describes the security properties of the TechSecure infrastructure, the threat model it addresses, and the controls in place.

---

## Threat Model

| Threat | Mitigated By |
|---|---|
| Unauthorized remote access | VPN-only enforcement (firewall rule on DC01) |
| Certificate theft / leaked key | LDAP group check — cert alone is not sufficient |
| Revoked employee retaining access | Removing from `Techniciens_VPN` in AD immediately blocks VPN |
| Brute-force password attacks | Account lockout after 5 failed attempts (15 min) |
| Weak passwords | GPO complexity + 14-char minimum |
| Unattended workstation access | Screen lock after 10 minutes of inactivity |
| Undetected intrusion attempts | Audit logging — Event ID 4625 on every failed logon |
| Plaintext credential interception | AES-256-CBC encrypted tunnel, mutual TLS |

---

## Defense in Depth

```
Layer 1: Network
  └── VPN-only access enforced by DC01 firewall rule
      (blocks direct LAN connections from external hosts)

Layer 2: Transport
  └── Mutual TLS via X.509 certificates (CA: TechSecure-CA)
      AES-256-CBC cipher

Layer 3: Authentication
  └── AD credentials validated via LDAP / RADIUS
      (username + password, bound to Active Directory)

Layer 4: Authorization
  └── openvpn-auth-ldap enforces Techniciens_VPN group membership
      Certificate + valid credentials alone are insufficient

Layer 5: Endpoint
  └── GPO enforces password complexity, lockout, screen lock
      All workstations are domain-joined (TECHSECURE)

Layer 6: Audit
  └── Windows Security Log (4624/4625)
      OpenVPN journal (journalctl -u openvpn@server)
```

---

## Negative Security Test Results

A simulation of an insider threat was conducted:

- User `madara` — has a valid X.509 certificate signed by TechSecure-CA
- `madara` has correct AD credentials
- `madara` is **not** a member of `Techniciens_VPN`

**Result:** Connection rejected.

The server logs show two distinct phases:
1. **TLS verification** → `VERIFY OK: CN=madara` (certificate is valid)
2. **LDAP authorization** → `AUTH_FAILED` (user not in required group)

This confirms that certificate possession does not bypass group-based access control.

---

## Known Limitations (Lab Environment)

- TLS is disabled on the LDAP connection (`TLSEnable no`). In production, use LDAPS (port 636) with a valid certificate on the DC.
- The LDAP bind uses the domain Administrator account. In production, create a **dedicated read-only service account** with minimal permissions.
- The shared RADIUS secret (`testing123`) should be replaced with a strong, randomly generated value.
- Private keys are stored in the VM filesystem. In production, consider a hardware security module (HSM) or at minimum encrypted storage.

---

## 2FA Status

TOTP-based 2FA using `libpam-google-authenticator` was implemented and tested:

- **Approach 1 (PAM stacking):** Functional in isolation but produced intermittent failures due to `forward_pass` interactions between PAM modules.
- **Approach 2 (RADIUS + TOTP):** Tested; FreeRADIUS ↔ AD validated. Integration with OpenVPN hit permission and timeout issues in the virtualized environment.

2FA is **not enabled in the final deployment** but is documented as a recommended next step for production hardening.
