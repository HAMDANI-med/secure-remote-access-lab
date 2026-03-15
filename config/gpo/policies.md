# GPO Security Policies Reference

Applied via **Group Policy Management (gpmc.msc)** on DC01.
Policies apply to all computers and users in `techsecure.local`.

---

## Password Policy

**Path:** `Default Domain Policy → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Password Policy`

| Setting | Configured Value | GPO Key |
|---|---|---|
| Minimum password length | 14 characters | `MinimumPasswordLength` |
| Password must meet complexity requirements | Enabled | `PasswordComplexity` |
| Enforce password history | 5 passwords | `PasswordHistorySize` |
| Maximum password age | 90 days | `MaximumPasswordAge` |
| Minimum password age | 1 day | `MinimumPasswordAge` |
| Store passwords using reversible encryption | Disabled | `ClearTextPassword` |

**Complexity requirements (when enabled):**
- At least one uppercase letter (A–Z)
- At least one lowercase letter (a–z)
- At least one digit (0–9) or non-alphabetic character
- Password must not contain the user's account name or parts of the full name

---

## Account Lockout Policy

**Path:** `Default Domain Policy → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Account Lockout Policy`

| Setting | Configured Value |
|---|---|
| Account lockout threshold | **5** invalid logon attempts |
| Account lockout duration | **15 minutes** |
| Reset account lockout counter after | 15 minutes |

Protects against brute-force and password spraying attacks.

---

## Screen Lock (Inactivity)

**Path:** `Default Domain Policy → User Configuration → Policies → Administrative Templates → Control Panel → Personalization`

| Setting | Configured Value |
|---|---|
| Enable screen saver | **Enabled** |
| Password protect the screen saver | **Enabled** |
| Screen saver timeout | **600 seconds** (10 minutes) |

Prevents unauthorized access to unattended workstations.

---

## Audit Policy

**Path:** `Default Domain Policy → Computer Configuration → Policies → Windows Settings → Security Settings → Advanced Audit Policy Configuration → Logon/Logoff`

| Audit Category | Success | Failure |
|---|---|---|
| Audit Logon | ✅ | ✅ |
| Audit Logoff | ✅ | — |
| Audit Account Lockout | — | ✅ |

**Relevant Event IDs (Security Log):**

| Event ID | Meaning |
|---|---|
| **4624** | Successful logon |
| **4625** | Failed logon attempt |
| **4740** | Account locked out |
| **4767** | Account unlocked |

View in: **Event Viewer (`eventvwr.msc`) → Windows Logs → Security**

---

## Applying / Refreshing GPO

To force an immediate refresh on a client:

```cmd
gpupdate /force
```

To verify applied policies:

```cmd
gpresult /r
```
