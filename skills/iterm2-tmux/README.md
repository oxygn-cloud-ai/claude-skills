# iterm2-tmux

One iTerm2 tab per tmux session, auto-bootstrapped from a directory of project folders. Each tab gets a unique color and optional watermark background image.

## How It Works

```
tmux-iterm-tabs.sh  (orchestrator)
  |
  +-- tmux-sessions.sh     Creates one tmux session per subdirectory in TMUX_REPOS_DIR
  |
  +-- gen-session-bg.py    Generates watermark background images (optional)
  |
  +-- AppleScript          Opens one iTerm2 tab per unattached session
       |
       +-- tmux-attach-session.sh    Sets tab color, title, background, then attaches

tmux-picker.sh     Standalone interactive session picker (for SSH/remote use)
```

## Requirements

- **macOS** (AppleScript-based tab creation is macOS-only)
- **iTerm2** (Homebrew: `brew install --cask iterm2`)
- **tmux** (Homebrew: `brew install tmux`)
- **Python 3 + Pillow** (optional, for background images: `pip3 install Pillow`)

## Installation

```bash
cd skills/iterm2-tmux
./install.sh
```

The installer will:
1. Ask for the directory containing your project subdirectories
2. Set up `~/.tmux.conf` with required settings
3. Install scripts to `~/.local/bin` (symlinked by default)
4. Optionally import iTerm2 preferences

### Options

```
./install.sh              Interactive install (symlink mode)
./install.sh --copy       Copy scripts instead of symlinking
./install.sh --check      Verify installation health
./install.sh --uninstall  Remove installed scripts
./install.sh --help       Full help

INSTALL_DIR=~/bin ./install.sh    Install to ~/bin instead
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_REPOS_DIR` | `~/Repos` | Directory containing subdirectories for tmux sessions |
| `TMUX_SESSIONS_SCRIPT` | (auto-detected) | Path to tmux-sessions.sh |
| `INSTALL_DIR` | `~/.local/bin` | Where scripts are installed |

Configuration is stored in `~/.config/iterm2-tmux/config` and sourced by the scripts automatically.

You can also set `TMUX_REPOS_DIR` in your shell profile to override the config file.

## iTerm2 Settings

These iTerm2 preferences improve the tmux integration:

- **Auto-hide tmux client session**: Preferences > General > tmux
- **Sync clipboard**: Preferences > General > tmux
- **Open no windows at startup**: Preferences > General > Startup

The installer can import a pre-configured plist with these settings enabled.

## tmux Configuration

The scripts require these two settings in `~/.tmux.conf`:

```
set-option -g set-titles off
set-option -g allow-rename off
```

These prevent tmux from overwriting the tab titles set by the scripts. The installer adds them automatically.

## Remote / SSH Usage

`tmux-picker.sh` is a standalone interactive session picker that works over SSH:

```bash
# Add to ~/.ssh/rc or call from shell profile
/path/to/tmux-picker.sh
```

It lists all tmux sessions, highlights attached ones, and lets you choose which to join.

## Customization

### Tab Colors

Edit the `TAB_COLORS` array in `tmux-attach-session.sh` and the matching `ACCENTS` list in `gen-session-bg.py`. Both use RGB values (0-255 per channel). The 12-color palette cycles for sessions beyond 12.

### Background Images

`gen-session-bg.py` generates 1920x1080 PNG images with:
- Session name as a centered watermark (opacity 40/255)
- Thin colored accent stripe at top
- System fonts (Menlo, Monaco) with fallback

To disable background images, remove or rename `gen-session-bg.py`.

## Uninstall

```bash
cd skills/iterm2-tmux
./uninstall.sh
```

This removes scripts from the install directory and the config file. It does **not** modify `~/.tmux.conf` or iTerm2 preferences.

## License

MIT (same as parent repo)
