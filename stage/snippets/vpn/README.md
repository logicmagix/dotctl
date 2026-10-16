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
vpnctl up [file]        Foreground connect (exec openvpn; used by systemd)
vpnctl off              Disconnect
vpnctl status           Process / interface / public IP
vpnctl list [filter]    List available .ovpn configs
vpnctl random           Pick random server and connect (skips retired servers)
vpnctl stale            List configs whose server no longer resolves
vpnctl use <file>       Set the default config without connecting
vpnctl pick             Interactive fzf picker
vpnctl killswitch on    Enable iptables kill switch (block non-tun0)
vpnctl killswitch off
vpnctl killswitch stat
vpnctl autostart on     Connect at boot (installs an OpenRC/systemd unit if needed)
vpnctl autostart off    Do not connect at boot
vpnctl autostart stat   Show whether the boot unit is enabled
vpnctl menu             wofi menu (what the waybar button calls)
```

The waybar button calls `vpnctl menu` on click, which presents a wofi
dmenu for connect/disconnect/killswitch/pick-server/status, plus a
`Connect at boot: ON|OFF` entry that toggles `vpnctl autostart`.

## 5. Auto-start at boot (optional)

By default `vpnctl` is a manual CLI - nothing starts it on login or boot.
To have the tunnel come up automatically, pick `Connect at boot: OFF` in
the waybar menu (it flips to `ON`), or run:

```bash
vpnctl autostart on      # connect at boot
vpnctl autostart off     # stay disconnected at boot
vpnctl autostart stat    # which is it right now?
```

`autostart` detects the init system and manages one unit for it:

| Init    | Unit                                   | Boot action  |
|---------|----------------------------------------|--------------|
| OpenRC  | `/etc/init.d/vpnctl` in `default`      | `vpnctl on`  |
| systemd | `/etc/systemd/system/vpnctl.service`   | `vpnctl up`  |

The unit is generated on the first `autostart on` (nothing is written if
it already exists) and left in place by `autostart off`, which only drops
it from the boot set. Toggling never touches the current connection. The
boot connect uses whatever `/etc/openvpn/nordvpn.conf` points at, so
`vpnctl use <file>` (or any connect from the menu) also picks the server
for next boot.

If you need `network-online.target` (systemd) or `net` (OpenRC) to
actually wait for the network rather than resolving instantly, enable
whichever wait helper your network stack provides - for systemd:

```bash
# NetworkManager:
sudo systemctl enable NetworkManager-wait-online.service
# or systemd-networkd:
sudo systemctl enable systemd-networkd-wait-online.service
```

### systemd details

The unit is the same file that ships at `stage/snippets/vpn/vpnctl.service`
(install it by hand with `install -m644` + `systemctl daemon-reload` +
`systemctl enable` if you prefer). It calls `vpnctl up`, which `exec`s
`openvpn` in the foreground so systemd tracks the real process, can stop
it cleanly with `SIGTERM`, and restarts it on failure.

```bash
systemctl status vpnctl.service
journalctl -u vpnctl.service -f
```

`vpnctl off` and the menu's Disconnect stop the unit before killing
openvpn, so `Restart=on-failure` does not bring the tunnel back. Driving
it with `sudo systemctl start|stop|restart vpnctl` also works.

#### Stop OpenVPN log spam on the greeter TTY

With `vpnctl.service` enabled, OpenVPN starts early enough that its
verbose connect output can land on the same VT your display manager is
claiming - you end up staring at a greeter decorated with `TLS:
Initial packet from ...`, route adds, and ifconfig lines.

Fix: order the display manager after `vpnctl.service` via a drop-in
override. For [greetd](https://sr.ht/~kennylevinsen/greetd/):

```bash
sudo mkdir -p /etc/systemd/system/greetd.service.d
sudo tee /etc/systemd/system/greetd.service.d/override.conf >/dev/null <<'EOF'
[Unit]
After=vpnctl.service network-online.target
Wants=network-online.target
EOF
sudo systemctl daemon-reload
```

For other display managers, substitute the unit name
(`sddm.service.d/`, `gdm.service.d/`, `lightdm.service.d/`, ...). Chain
extra units into `After=` if you run companion services (e.g. a
`nordvpn-watch.service` that reacts to tunnel state) that also log to
the console.

### OpenRC details (Gentoo / Artix)

The generated `/etc/init.d/vpnctl` is a plain `start()` / `stop()` script
around `vpnctl on` / `vpnctl off` - no `supervise-daemon`. That is
deliberate: a supervisor respawns openvpn on any exit, including a clean
`vpnctl off`, so the tunnel becomes impossible to turn off from the
waybar module. Runtime control stays with `vpnctl` and the menu whether
or not the service is in the runlevel.

If you already have a hand-rolled `/etc/init.d/vpn` that calls `vpnctl`,
`autostart` keeps driving that one instead of installing a twin.

```bash
sudo rc-service vpnctl start|stop|status
rc-update show default | grep vpnctl
```

OpenRC's stock `openvpn` init script (`ln -s /etc/init.d/openvpn
/etc/init.d/openvpn.nordvpn`) is an alternative, but it does not pass
`--auth-user-pass`, so provider configs with a bare `auth-user-pass`
line (NordVPN's) hang on a credential prompt at boot. Use it only if you
edit the config to `auth-user-pass /etc/openvpn/nordvpn.auth`.

## 6. Sudo behavior

`vpnctl` needs root for `openvpn`, `iptables`, `ip6tables`, `kill`, and
`rm /run/openvpn-*.pid`; `vpnctl autostart` additionally needs
`rc-update` or `systemctl` (and `tee` + `chmod` into `/etc/init.d` or
`/etc/systemd/system` the first time). It re-invokes itself with `sudo`
when needed. Every menu action runs in a terminal window, so a password
prompt there works; to avoid one every click, add a sudoers drop-in:

```
# /etc/sudoers.d/dotctl-vpn
yourname ALL=(root) NOPASSWD: /usr/sbin/openvpn, /usr/sbin/iptables, /usr/sbin/ip6tables, /bin/kill, /bin/rm /run/openvpn-*.pid
```

(Paths may differ on your distro - adjust with `command -v openvpn`, etc.)

## 7. Troubleshooting

- **Button shows nothing**: `vpn-status-indicator` probably isn't on PATH,
  or waybar's config still references `~/.local/bin/vpn-status-indicator`
  while the scripts live in `/usr/local/bin`. Fix the path in the jsonc.
- **State stuck on OFF**: run `ip link show tun0` - if it says "does not
  exist", OpenVPN isn't actually connected. Try `vpnctl status` for details.
- **`vpnctl on` reports "no tun0 after 30s"**: the server in the config is
  unreachable. Providers retire servers without notice, and a pool of
  `.ovpn` files downloaded months ago can be a third dead - the process
  sits retrying a remote that will never answer while the indicator
  correctly shows OFF. Run `vpnctl stale` to list the dead configs
  (`vpnctl stale | sed "s#^#$HOME/nordvpn/ovpn_udp/#" | xargs rm` prunes
  them), or download a fresh set from your provider. `vpnctl random`
  already skips configs whose hostname no longer resolves. OpenVPN's
  output for `vpnctl on` lands in `/var/log/openvpn/nordvpn.log`; raise
  the wait with `VPNCTL_CONNECT_TIMEOUT=60 vpnctl on` on slow links.
  `vpnctl on` rotates that log (`.1`, `.2`) once it passes 10 MB; tune
  with `VPNCTL_LOG_MAX_MB`.
- **Killswitch class never triggers**: the script checks `iptables -S OUTPUT`
  for a rule matching `! -o tun0 ... -j REJECT`. If you use a different
  interface or firewall (ufw, firewalld, nftables), edit the `iptables`
  block in `vpn-status-indicator` to match.
