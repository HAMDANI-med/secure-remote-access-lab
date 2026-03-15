# Network Architecture

## IP Addressing Plan

| Host | Interface | Address | Description |
|---|---|---|---|
| DC01 | ens0 (LAN) | 192.168.10.10/24 | Domain Controller, DNS |
| VPN01 | ens36 (LAN) | 192.168.10.11/24 | VPN gateway, RADIUS, CA |
| VPN01 | ens33 (NAT) | DHCP | Internet access for package installs |
| CLIENT01 | ens0 (LAN) | 192.168.10.20/24 | Domain workstation |
| VPN clients | tun0 (virtual) | 10.8.0.x/24 | Assigned dynamically by OpenVPN |

## Routing

DC01 uses **VPN01 (192.168.10.11) as its default gateway**.  
This is required so that DC01 can send replies back to VPN clients on the `10.8.0.0/24` subnet — addresses it would otherwise not know how to reach.

```
DC01 (192.168.10.10)
  └── Default GW: 192.168.10.11  ──►  VPN01 routes to 10.8.0.x
```

VPN01 has IP forwarding enabled:
```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl --system
```

## Firewall Rule on DC01

A Windows Defender inbound rule **blocks direct ICMP (ping) from CLIENT01's physical IP** (`192.168.10.20`). This enforces the policy that remote workstations must connect through the VPN tunnel.

When the VPN is active, CLIENT01 communicates with DC01 using its virtual IP (`10.8.0.x`), which is not blocked. When the VPN is inactive, all traffic is dropped.

## Ports Summary

| Port | Protocol | Service | Direction |
|---|---|---|---|
| 1194 | UDP | OpenVPN | CLIENT01 → VPN01 |
| 389 | TCP | LDAP | VPN01 → DC01 |
| 53 | UDP/TCP | DNS | Clients (via VPN) → DC01 |
| 1812 | UDP | RADIUS | OpenVPN (PAM) → FreeRADIUS (localhost) |
| 8000 | TCP | Temporary HTTP | CLIENT01 → VPN01 (file transfer only) |
