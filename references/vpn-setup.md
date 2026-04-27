# HPI VPN Setup

The HPI cluster sits behind a VPN. Before any `ssh hpi-cluster` command, confirm the tunnel is up.

## Prerequisites

1. **`.ovpn` file** — provided by HPI (typically `SC_User.ovpn`).
2. **Automated auth (optional)** — if you use an auth file, keep it outside this repo, restrict it with `chmod 600`, and reference it from the `.ovpn` using `auth-user-pass` as described in the official VPN docs.

The commands below assume the VPN profile directory is referred to as the "ovpn-dir".

## Connecting

**Check if already running:**

```bash
pgrep -af openvpn
```

### Tunnelblick (macOS GUI)

Install your `.ovpn` as a Tunnelblick profile (`.tblk`). Connect via the menu bar icon or:

```bash
osascript -e 'tell application "Tunnelblick" to connect "<profile-name>"'
```

### CLI — macOS (agent-friendly)

In non-interactive terminals (VS Code integrated terminal, AI agents), `sudo` cannot prompt for a password. Use `osascript` to trigger the native macOS password dialog:

```bash
osascript -e 'do shell script "openvpn --config /path/to/your.ovpn --cd /path/to/ovpn-dir --daemon --log /tmp/openvpn-hpi.log" with administrator privileges'
```

`--cd` must point to the directory containing the `.ovpn` file and any auth file referenced by relative path.

### CLI — Linux

```bash
sudo openvpn --config /path/to/your.ovpn --cd /path/to/ovpn-dir --daemon --log /tmp/openvpn-hpi.log
```

## Verifying

```bash
ssh -o ConnectTimeout=5 hpi-cluster hostname   # expect: a login-node hostname
```

## Disconnecting

**macOS:**
```bash
osascript -e 'do shell script "killall openvpn" with administrator privileges'
```
Or disconnect from the Tunnelblick menu bar.

**Linux:**
```bash
sudo killall openvpn
```

## Split-tunnel tip

The default HPI `.ovpn` routes *all* traffic through the VPN (full tunnel). If you only need access to the cluster network, add these lines to your `.ovpn`:

```
pull-filter ignore "redirect-gateway"
route <cluster-subnet> 255.255.0.0     # e.g. the 10.x.x.x/16 range from your .ovpn
```

This sends only cluster traffic through the tunnel and leaves the rest of your internet untouched.

## VPN MTU troubleshooting

The official troubleshooting page for `https://docs.sc.hpi.de/VPN/Troubleshooting/` documents VPN MTU issues and recommends adding this line to the `.ovpn` file when SSH times out:

```
tun-mtu 1400
```

If SSH still hangs at key exchange on a local OpenSSH client, this local workaround has also helped: add `KexAlgorithms curve25519-sha256` to the `hpi-cluster` block in `~/.ssh/config`:

```
Host hpi-cluster
    HostName hpc.sci.hpi.de
    User <your-hpi-username>
    IdentityFile ~/.ssh/<your-key>
    IdentitiesOnly yes
    KexAlgorithms curve25519-sha256
```
