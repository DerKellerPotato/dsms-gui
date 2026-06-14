# Using DSMS Control Center

The graphical way to manage DSMS. It edits `/etc/dsms/dsms.conf` through forms,
applies the configuration, joins the domain and imports/exports config files.

## Starting

- Application menu → **DSMS Control Center**, or
- terminal: `dsms-gui`

The app runs as your normal user. Anything that changes the system goes through
`pkexec` and shows the standard authentication dialog — the GUI itself never
runs as root. It drives the **`dsms`** command-line tool (a package
dependency); if that is missing, the Status tab tells you how to install it.

Runtime deps: `python3-gi` + `gir1.2-gtk-3.0` (preinstalled on Mint/Ubuntu;
otherwise `sudo apt install python3-gi gir1.2-gtk-3.0`).

## First start / setup wizard

If no `/etc/dsms/dsms.conf` exists, the app offers the **setup wizard**:

1. **Domain** — directory type (AD / Synology / LDAP), domain name, server.
2. **Home & Network** — home directory mode, SMB share, DNS server, sudo groups.
3. **Finish** — optionally install packages + apply immediately (`dsms apply
   --full`), and join the domain (asks for admin credentials).

The wizard covers the common settings; everything else is on the tabs, and
every option is documented in `/etc/dsms/dsms.conf.example`. Re-run it any time
from the ☰ menu.

## Main window

| Tab | Contents |
|-----|----------|
| **Status** | Output of `dsms status` (SSSD, domain membership, home mode, sync timer) + a "test user lookup" field |
| **Domain** | Directory type, AD and LDAP connection settings, join account |
| **Home Directory** | Mode, SMB share, shell, allowed groups, offline days |
| **Network & System** | Hostname, DNS, hosts entries, Avahi, NTP, sudo/polkit/hardware groups, login screen |
| **SSH Sync** | Sync server, key, timeouts, change detection |

Every field has a tooltip — hover over the label or the input.

### Buttons & menu

- **Save** — writes the form values to `/etc/dsms/dsms.conf`
  (`pkexec dsms import`; validated before installing).
- **Apply to System** — re-applies the saved config to SSSD, PAM, NSS, network,
  login manager and privileges (`pkexec dsms apply`). Save first, then apply.
- **☰ → Setup wizard…** — re-run the guided setup.
- **☰ → Join domain…** — asks for a domain admin account + password and runs
  the join. The password is piped to `realm join` and never stored.
- **☰ → Import / Export configuration…** — load a `.conf` into the form, or save
  the current values to a file (mode 600). **Exports may contain passwords.**
- **☰ → Update from GitHub…** — fetch and reinstall the latest `dsms` + `dsms-gui`
  from GitHub (debug; requires `git`; restart the app afterwards).

## Typical workflows

**Change the home share on an existing machine**

1. Home Directory tab → adjust *SMB server* / *Share name*
2. **Save** → **Apply to System**
3. Users get the new mount at next login.

**Roll a config from machine A to machine B**

```text
A: ☰ → Export configuration… → dsms-site.conf   (or: dsms export dsms-site.conf)
B: ☰ → Import configuration… → Save → Apply to System → Join domain…
```

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| App doesn't start, `ModuleNotFoundError: gi` | `sudo apt install python3-gi gir1.2-gtk-3.0` |
| "dsms command not found" on the Status tab | Install the CLI: `sudo apt install dsms-gui` (pulls dsms), or ☰ → Update from GitHub |
| No authentication dialog appears | polkit agent not running (rare outside desktop sessions); use the CLI over SSH instead |
| Save fails with "not a valid DSMS config" | `DOMAIN_TYPE` must be `ad`, `ldap` or `none` |
