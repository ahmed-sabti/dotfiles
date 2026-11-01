# Dotfiles

Shared terminal and desktop configuration for my machines (Arch/CachyOS, Fedora, Ubuntu, macOS), managed with
[chezmoi](https://chezmoi.io):

- **One repo, several machines:** machine roles (`mac`, `laptop`, `gaming`, `server`) and per-host layers for KDE Plasma.
- **Reproducible desktop:** packages, Flatpaks, themes and KDE settings from layered lists and snapshots.
- **Browser hardening:** Firefox (Betterfox + policies) and Brave policies with telemetry off.
- **CI:** every push validates the shell scripts and JSON configs (`scripts/validate.sh`).

## Install

```bash
./install.sh      # installs chezmoi if missing, then: chezmoi init --source <this repo> --apply
```

Managed by [chezmoi](https://chezmoi.io). `.chezmoiroot` points at `home/`, which mirrors `$HOME`
(`dot_zshrc` -> `~/.zshrc`, `dot_config/nvim/init.lua` -> `~/.config/nvim/init.lua`, ...).
Everything outside `home/` (scripts, reference configs, firefox/) is not copied as-is.

- **Symlink mode**: plain files become symlinks into this repo, so editing either side is live,
  like the old `install.sh`. Templates (`*.tmpl`) are rendered into real files.
- **Per machine**: `chezmoi init` asks once for `role` (mac, laptop, gaming, server) and `hypr`
  (install the Hyprland rice). `home/.chezmoiignore` skips Linux desktop files on macOS and
  desktop files on servers. `~/.zshrc.local` is rendered from `home/.chezmoitemplates/`.
- **Scripts** run only during `chezmoi apply`, and each says what it changed:
  - `run_after_firefox.sh` sets up Firefox/Zen/LibreWolf: `firefox/policies.json`
    (telemetry off, uBlock Origin + Bitwarden + Catppuccin forced/installed, SearXNG default,
    uBlock filter lists) and `user.js` = `firefox/betterfox.js` (Betterfox 154) +
    `firefox/user-overrides.js` in every profile. macOS: policies go into the browser's
    preferences domain (signed app bundles can't be written).
  - `run_once_after_hyprland.sh` copies `reference/{hypr,waybar,swaync,wofi}` once (hypr=true only).

Day to day: edit files in the repo (they are live), `chezmoi apply` after adding files or
changing templates, `chezmoi diff` to preview.

## KDE desktops

`kde/apply.sh` sets up a Plasma machine (packages, Flatpaks, npm globals, chezmoi, KDE configs,
theme, wallpaper) from layers, so another distro or machine is one more directory:

- `kde/common/` - every machine: Flatpak and npm lists, app-id aliases between distros, and
  `theme.sh`: "Dotfiles Dark" / "Dotfiles Light" global themes (copies of Breeze with Catppuccin /
  Papirus / Bibata-Modern-Ice), used by the light/dark switch so it no longer resets the cursor
  and icons, plus the same cursor on the login screen (Plasma Login Manager or SDDM).
- `kde/os/<id>/` - per distro, picked from `/etc/os-release` `ID`, then `ID_LIKE` (CachyOS -> `arch`):
  `install.sh` and its package lists, optional `rewrite.sed` for the copied configs.
  `os/ubuntu/` holds the ubuntu-desk container setup.
- `kde/hosts/<name>/` - per machine, matched by hostname (or `--host NAME`): `host.conf`
  (`ROLE` for chezmoi, `CONFIG_FROM` = whose snapshot to use, optional theme overrides),
  `config/` from `kde/snapshot.sh`, optional `rewrite.sed` / `tweaks.sh`.
  The T480 is the reference; the gaming PC uses its snapshot.

New distro: add `kde/os/<id>/install.sh` (+ package list). New machine: add
`kde/hosts/<name>/host.conf`. After changing the desktop on the T480: `kde/snapshot.sh`, commit,
then `kde/apply.sh --kde-only` elsewhere.

Wallpapers referenced by the Hyprland configs are not included in this public copy.

## Neovim

Plugins are pinned in `home/dot_config/nvim/lazy-lock.json` (lazy.nvim updates it in place;
commit it after `:Lazy update`). nvim-treesitter's `main` branch builds parsers with the
`tree-sitter` CLI: `brew install tree-sitter-cli` / `pacman -S tree-sitter-cli` / `dnf install tree-sitter-cli`.
Language servers come from Mason; linters/formatters (ruff, shellcheck, shfmt, stylua, hadolint,
codespell) are used when installed and skipped otherwise.

## Secrets

Nothing credential-bearing belongs in this repo, and none of it is stored in a
plaintext file any more.

- **Git credentials** live in the **macOS Keychain**. `git/gitconfig` sets
  `credential.helper = osxkeychain`, with `github.com` and `gist.github.com`
  delegated to `gh auth git-credential`. There is no `git/credentials` file —
  the `.gitignore` entries for it are historical.
- **On Linux hosts** the `osxkeychain` helper does not exist; those machines
  fall back to whatever helper they configure locally. The GitHub override is
  keyed by host, so it is inert elsewhere.
- Keep any other tokens in the platform keychain, never in Git history.
