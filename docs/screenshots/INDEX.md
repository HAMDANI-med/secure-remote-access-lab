# Screenshots

Visual proof-of-work captures organized by deployment phase.

---

## 1. Network Configuration

| File | Description |
|---|---|
| `01_dc01_vm_network_settings.png` | DC01 VM assigned to `techsecure` LAN segment |
| `02_dc01_ip_config_*.png` | DC01 static IP: 192.168.10.10, DNS: 127.0.0.1 |
| `03_client_vm_settings_*.png` | CLIENT01 VM assigned to same LAN segment |
| `04_client_ip_config_*.png` | CLIENT01 static IP: 192.168.10.20, DNS: 192.168.10.10 |
| `05_ping_dc01_from_client_*.png` | Successful ping from CLIENT01 to DC01 (0% loss) |
| `06_vpn01_dual_nic_settings_*.png` | VPN01 with two NICs: LAN segment + NAT |
| `07_vpn01_network_interfaces_*.png` | `/etc/network/interfaces` with static 192.168.10.11 |
| `08_vpn01_ping_google_and_dc01_*.png` | VPN01 pinging Google (NAT) and DC01 (LAN) |

---

## 2. Active Directory Deployment

| File | Description |
|---|---|
| `09_adds_role_install_*.png` | Server Manager — AD DS + DNS roles selected |
| `10_adds_role_install_progress_*.png` | Role installation progress and completion |
| `11_domain_promotion_new_forest_*.png` | AD DS wizard — new forest `techsecure.local` |
| `12_domain_admin_login_*.png` | Login screen showing `TECHSECURE\Administrateur` |
| `13_ad_ou_structure_*.png` | ADUC showing TechSecure-Corp OU tree and security groups |
| `14_user_creation_hamdanimed_*.png` | New user wizard for `hamdanimed@techsecure.local` |
| `15_client_join_domain_*.png` | CLIENT01 system properties — joined to `techsecure.local` |
| `16_whoami_domain_auth_*.png` | `whoami` returns `techsecure\hamdanimed` |

---

## 3. GPO Security Policies

| File | Description |
|---|---|
| `17_gpo_password_policy_*.png` | Default Domain Policy — password settings (14 chars, complexity) |
| `18_gpo_lockout_policy_*.png` | Account lockout: 5 attempts, 15 min duration |
| `19_gpo_screensaver_*.png` | Screensaver GPO — 600s timeout with password |
| `20_gpo_audit_policy_*.png` | Audit logon success/failure enabled |
| `21_gpo_complexity_test_fail_*.png` | AD rejects password "123" — complexity policy enforced |
| `22_account_locked_screen_*.png` | Login screen showing account locked message |
| `23_event_id_4625_audit.png` | Event Viewer — Security log, Event ID 4625 (failed logon) |

---

## 4. PKI & OpenVPN Server

| File | Description |
|---|---|
| `24_openvpn_easyRSA_init_*.png` | `./easyrsa init-pki` — PKI directory created |
| `25_ca_build_*.png` | `./easyrsa build-ca nopass` — CA created (CN: TechSecure-CA) |
| `26_server_cert_*.png` | Server certificate request and signing |
| `27_dh_and_client_cert_*.png` | DH params generated; `hamdanimed` client cert signed |
| `28_server_conf_*.png` | `/etc/openvpn/server.conf` in editor |
| `29_openvpn_service_running.png` | `systemctl status openvpn@server` — **active (running)** |

---

## 5. Client & VPN Validation

| File | Description |
|---|---|
| `30_http_server_file_transfer.png` | Python HTTP server serving cert files; client browser download |

*(Additional screenshots from pages 31–30 of the original report cover VPN connect status "Securely Connected", IP 10.8.0.6, ping through tunnel, LDAP auth logs, RADIUS config, and negative test results.)*

---

## 6. LDAP & RADIUS Authentication

Logs visible in `journalctl -u openvpn@server` captures:
- `VERIFY OK: CN=TechSecure-CA` → CA chain validated
- `VERIFY OK: CN=hamdanimed` → client cert validated
- `Accepted google_authenticator for hamdanimed` → 2FA accepted (test only)
- `AUTH_FAILED` for user `madara` → not in `Techniciens_VPN` group

---

*All screenshots are direct captures from the lab environment.*
