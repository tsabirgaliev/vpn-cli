# vpn-cli

Start and stop the Check Point Endpoint Security VPN (`trac`) from an AI agent without the
agent ever seeing the password. Each connect, and each password change, needs Touch ID.

| Command | Approval | What it does |
|---|---|---|
| `sudo vpnctl set-password [user@site]` | Touch ID, then you type the password | Saves or replaces the password for `user@site` in the System keychain. Without an argument, uses the client's active site and its username |
| `sudo vpnctl up` | Touch ID | Connects to the client's active site as its configured username; the password never appears on a command line |
| `sudo vpnctl down` | none | Disconnects |
| `sudo vpnctl status` | none | Shows the connection state |

No sudoers rule is installed, so `sudo vpnctl` asks for your Mac password like any other sudo
command.

## How it works

```
agent (runs as you) ───sudo vpnctl up────▶ vpnctl (root)
                                             ├─ 1. gets the active site and its username from `trac info`
                                             ├─ 2. touchid-gate in your GUI session ("Connect VPN to <site>")
                                             ├─ 3. reads that username's password from /Library/Keychains/System.keychain (root only)
                                             └─ 4. expect types both into `trac connect` at its prompts
```

- The password is only in the System keychain, root's memory and `trac`'s prompt input. It is
  never in an argument list, a file you own or the agent's environment.
- The prompt text is fixed in `vpnctl`, so the agent cannot make it say something else.
- `touchid-gate` is started and waited on by root, so the agent cannot fake an approval.
  Hardened runtime blocks other processes running as you from injecting into it.
- sudo's default `env_reset` strips `DYLD_*`, `PATH` and similar variables.

## Files

| File | Installed to |
|---|---|
| `touchid-gate.swift` | built into `/usr/local/libexec/touchid-gate` |
| `vpnctl` | `/usr/local/sbin/vpnctl` |
| `install.sh` / `uninstall.sh` | run from this folder |

## Install

Run in your own Terminal, not through the agent:

```bash
./install.sh
sudo vpnctl set-password                       # Touch ID, then the password twice (for the active user@site)
security delete-generic-password -s <site>      # remove the copy the agent could read
security find-internet-password -s <site>       # check for other copies; delete with delete-internet-password
sudo vpnctl up
```

`<site>` is the connection name shown by `trac info`. After that,
`security find-generic-password -s <site> -w` without sudo must fail with "item could not be found".

The only setting at the top of `vpnctl` is `TRAC` (path to `trac`). Site and username come from
the client: `up` uses the connection marked `active site: true` in `trac info` and the username
it has for it, and picks the keychain item saved for that `user@site`. After switching site or
username in the client, run `set-password` again.

Uninstall with `./uninstall.sh` (add `--purge` to also delete the stored passwords).

## Before relying on it

- **Approve only the expected prompts:** "Connect VPN to <site>" or
  "Set VPN password for <user>@<site>". Deny one you didn't expect.
- **The agent can start `set-password` too.** Approving it lets the agent store a wrong password,
  which breaks the VPN but does not reveal the real one. It refuses to run without a terminal.
- **Turn off saved credentials in the Endpoint Security VPN client.** Otherwise the agent can run
  `trac connect` directly and skip `vpnctl`.
- **Every path component must be owned by root.** `install.sh` checks and warns. If something
  under `/usr/local` is owned by you, move the files to a root-owned location such as `/opt/vpnctl/`.
- **Not yet tested:** the `trac` path; its password prompt text (`expect` looks for "assword");
  whether `trac` connects when run as root; whether the Touch ID prompt appears when started
  through `launchctl asuser`. Run `sudo vpnctl up` once from a normal Terminal to check all four.
- **Password-only authentication.** If the site needs a password plus an OTP or token, `trac`
  reports "Multiple authentication methods is not supported in command line" and this won't work.
- Touch ID only by default. For fallback to your Mac password (lid closed, keyboard without
  Touch ID), change the policy in `touchid-gate.swift` to `.deviceOwnerAuthentication`. Only a
  person can type into that system dialog.

## Alternative without the Swift helper

macOS ships Touch ID for sudo as `/usr/lib/pam/pam_tid.so`:

```bash
echo 'auth sufficient pam_tid.so' | sudo tee /etc/pam.d/sudo_local
```

Then remove the `touchid` calls from `vpnctl` and use this sudoers rule:

```
Defaults!/usr/local/sbin/vpnctl env_reset, timestamp_timeout=0
tair ALL=(root) /usr/local/sbin/vpnctl set-password, /usr/local/sbin/vpnctl up
tair ALL=(root) NOPASSWD: /usr/local/sbin/vpnctl down, /usr/local/sbin/vpnctl status
```

The agent must call `sudo vpnctl up` without `-n`. Trade-offs: the prompt is generic sudo text
that doesn't say which command asked; if Touch ID fails, sudo asks for your Mac password in the
agent's terminal; inside tmux it needs `pam_reattach`. Check `timestamp_timeout=0` takes effect by
running `sudo vpnctl up` twice in a row; if the second run doesn't prompt, use a global
`Defaults timestamp_timeout=0` instead.
