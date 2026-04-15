# dotctl VPN module (optional)

An OpenVPN-based VPN status button for waybar, driven by two scripts:

- **`vpn-status-indicator`** - every 5 seconds, reports VPN state as JSON
  for the waybar `custom/vpn` module. State is derived from the presence
  of a `tun0` interface and an `iptables` killswitch rule.
- **`vpnctl`** - CLI + wofi menu for starting/stopping the OpenVPN process,
  picking a server, and toggling the killswitch.

Both scripts ship to `/usr/local/bin/` when you run `install.sh`. The module
itself is **not** wired into any canonical waybar variant - this is an
opt-in feature. Paste the snippet into the variant(s) you want, then set
up `/etc/openvpn/` as described below.

---

## 1. Install the scripts

Running `install.sh` already installs both scripts into `/usr/local/bin/`.
To install them manually:

```bash
sudo install -Dm755 stage/modules/vpn-status-indicator /usr/local/bin/vpn-status-indicator
sudo install -Dm755 stage/modules/vpnctl               /usr/local/bin/vpnctl
```

Check they're on `PATH`:

```bash
command -v vpn-status-indicator
command -v vpnctl
```

## 2. Wire the waybar module

Pick the snippet matching the style you use:

| Style    | Snippet                          |
|----------|----------------------------------|
| console  | `console.jsonc.snippet` + `console.css.snippet` |
| bubble   | `bubble.jsonc.snippet` + `bubble.css.snippet`   |

For the **console** variant:

1. Open `~/.config/waybar/console_full/config.jsonc` (or `console_minimal`).
2. In `modules-right`, insert the pair `"custom/rsep-vpn", "custom/vpn",`
   where you want the VPN button to appear (typical spot: just before
   `"custom/rsep-pulse", "pulseaudio"`).
3. Paste the two module objects from `console.jsonc.snippet` into the
   module block below.
4. Append the rules from `console.css.snippet` to `console_full/style.css`.
5. Add `#custom-rsep-vpn,` to the chevron font-size selector list in that
   same file (search for `font-size: 20pt` and add the line above it).
6. Re-run `dotctl apply` (or restart waybar) to pick up the changes.

For **bubble**, do the analogous edits - bubble has no separator chevron,
so only `custom/vpn` gets added.

## 3. Set up `/etc/openvpn/`

The scripts expect a standard OpenVPN layout. They default to NordVPN's
filename conventions but work with any provider that ships `.ovpn` files.

### Minimal setup (one fixed server)

```bash
sudo mkdir -p /etc/openvpn
# 1. Place your server config file
sudo cp path/to/server.ovpn /etc/openvpn/nordvpn.conf
# 2. Write your credentials (username on line 1, password on line 2)
sudo tee /etc/openvpn/nordvpn.auth >/dev/null <<'EOF'
your_username
your_password
EOF
sudo chmod 600 /etc/openvpn/nordvpn.auth
```

That's the minimum for `vpnctl on` / `vpnctl off` to work. The
`vpn-status-indicator` script will start reporting state correctly
once `tun0` comes up.

### Multi-server setup (pick-a-server flow)

`vpnctl` also supports a pool of `.ovpn` configs and lets you switch
between them via `vpnctl pick` (fzf), `vpnctl random`, or the wofi menu.

1. Drop all your provider's `.ovpn` files into a single directory - by
   default `~/nordvpn/ovpn_udp/`. Override by editing the `OVPN_DIR`
   variable at the top of `/usr/local/bin/vpnctl`.
2. `/etc/openvpn/nordvpn.conf` should be a **symlink** into that pool.
   `vpnctl on <file>` will update the symlink automatically, or you can
   do it manually:

   ```bash
   sudo ln -sf ~/nordvpn/ovpn_udp/us1234.nordvpn.com.udp.ovpn /etc/openvpn/nordvpn.conf
   ```

### Configurable paths

Both scripts hardcode a small set of defaults at the top of the file.
If you use a different provider, different filenames, or a different
config dir, edit these in place after install:

**`/usr/local/bin/vpnctl`**
```bash
CONFIG_DIR="/etc/openvpn"
DEFAULT_CONF="${CONFIG_DIR}/nordvpn.conf"
AUTH_FILE="${CONFIG_DIR}/nordvpn.auth"
OVPN_DIR="/home/you/nordvpn/ovpn_udp"
PIDFILE="/run/openvpn-nordvpn.pid"
```

**`/usr/local/bin/vpn-status-indicator`**
```bash
CONFIG_DIR="/etc/openvpn"
DEFAULT_CONF="${CONFIG_DIR}/nordvpn.conf"
```

## 4. Usage

```
vpnctl on [file]        Connect using $DEFAULT_CONF (or pick an .ovpn file)
vpnctl off              Disconnect
vpnctl status           Process / interface / public IP
vpnctl list [filter]    List available .ovpn configs
vpnctl random           Pick random server and connect
vpnctl use <file>       Set the default config without connecting
vpnctl pick             Interactive fzf picker
vpnctl killswitch on    Enable iptables kill switch (block non-tun0)
vpnctl killswitch off
vpnctl killswitch stat
vpnctl menu             wofi menu (what the waybar button calls)
```

The waybar button calls `vpnctl menu` on click, which presents a wofi
dmenu for connect/disconnect/killswitch/pick-server/status.

## 5. Sudo behavior

`vpnctl` needs root for `openvpn`, `iptables`, `ip6tables`, `kill`, and
`tee /run/openvpn-*.pid`. It re-invokes itself with `sudo` when needed.
To avoid a password prompt every click, add a sudoers drop-in:

```
# /etc/sudoers.d/dotctl-vpn
yourname ALL=(root) NOPASSWD: /usr/sbin/openvpn, /usr/sbin/iptables, /usr/sbin/ip6tables, /bin/kill, /usr/bin/tee /run/openvpn-*.pid, /bin/rm /run/openvpn-*.pid
```

(Paths may differ on your distro - adjust with `command -v openvpn`, etc.)

## 6. Troubleshooting

- **Button shows nothing**: `vpn-status-indicator` probably isn't on PATH,
  or waybar's config still references `~/.local/bin/vpn-status-indicator`
  while the scripts live in `/usr/local/bin`. Fix the path in the jsonc.
- **State stuck on OFF**: run `ip link show tun0` - if it says "does not
  exist", OpenVPN isn't actually connected. Try `vpnctl status` for details.
- **Killswitch class never triggers**: the script checks `iptables -S OUTPUT`
  for a rule matching `! -o tun0 ... -j REJECT`. If you use a different
  interface or firewall (ufw, firewalld, nftables), edit the `iptables`
  block in `vpn-status-indicator` to match.
