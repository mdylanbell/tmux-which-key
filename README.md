# tmux-which-key

A LazyVim-style which-key popup for tmux. Press a trigger key to open a discoverable, keyboard-driven command menu with nested groups, breadcrumb navigation, and Nord-themed colors.

![Nord theme](https://img.shields.io/badge/theme-Nord-88C0D0?style=flat-square)
![tmux](https://img.shields.io/badge/tmux-3.3+-green?style=flat-square)

![tmux-which-key screenshot](https://gist.githubusercontent.com/Nucc/2eb50f2a324d8e79a8f231b16cdb3b4f/raw/screenshot.png)

## Features

- **Discoverable keybindings** - see all available commands at a glance
- **Nested groups** - organize commands hierarchically (git, window, session, etc.)
- **Breadcrumb navigation** - always know where you are in the menu tree
- **Nord color theme** - clean, readable color scheme using 24-bit true color
- **JSON configuration** - easy to customize, extend, and share
- **Five action types** - shell commands (with optional auto-execute), tmux commands, external scripts, popups, and nested groups
- **Single-keystroke input** - no Enter key required, instant response

## Requirements

- tmux >= 3.3 (for `display-popup` support)
- `jq` (for JSON parsing)
- A terminal with true color (24-bit) support

## Installation

### With [TPM](https://github.com/tmux-plugins/tpm) (recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'Nucc/tmux-which-key'
```

Then press `prefix + I` to install.

### Manual

Clone the repository:

```bash
git clone https://github.com/Nucc/tmux-which-key.git ~/.tmux/plugins/tmux-which-key
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-which-key/which-key.tmux
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Usage

Press `prefix + Space` (default) to open the which-key popup.

- **Press a key** to execute the corresponding command or enter a group
- **Escape** to go back one level or close the menu
- **Backspace** to go back one level or close the menu

Groups are indicated by a `+` prefix and shown in cyan. Pressing a group key opens its submenu with a breadcrumb showing your navigation path.

## Configuration

### Tmux Options

Set these in your `~/.tmux.conf` before loading the plugin:

| Option | Default | Description |
|--------|---------|-------------|
| `@which-key-trigger` | `Space` | Key binding (after prefix) to open the menu. Disable with `None`, `Off`, `Disabled`, `False`, or `0` |
| `@which-key-config` | _(auto-detected)_ | Path to a custom JSON config file |
| `@which-key-popup-height` | `16` | Popup height in lines |
| `@which-key-popup-width` | `100` | Popup width in characters |
| `@which-key-popup-bg` | `#2E3440` | Popup background color |
| `@which-key-popup-fg` | `#4C566A` | Popup border/foreground color |
| `@which-key-popup-x` | `C` | Popup X position (`C` = centered) |
| `@which-key-popup-y` | `S` | Popup Y position (`S` = status line) |
| `@which-key-color-key` | `#EBCB8B` | Menu key color |
| `@which-key-color-group` | `#88C0D0` | Group description color |
| `@which-key-color-desc` | `#D8DEE9` | Description and breadcrumb color |
| `@which-key-color-separator` | `#4C566A` | Separator, arrow, and footer hint color |
| `@which-key-color-header` | `#81A1C1` | Header title color |

Example:

```tmux
set -g @which-key-config '~/.config/tmux-which-key/config.json'
set -g @which-key-popup-height '20'
set -g @which-key-popup-width '120'
set -g @plugin 'Nucc/tmux-which-key'
```

### Theme Customization

You can override in-menu colors with tmux options (format must be `#RRGGBB`):

```tmux
set -g @which-key-color-key '#F9E2AF'
set -g @which-key-color-group '#89B4FA'
set -g @which-key-color-desc '#CDD6F4'
set -g @which-key-color-separator '#6C7086'
set -g @which-key-color-header '#74C7EC'
```

Invalid values fall back to defaults and show a one-time warning in tmux messages when the menu opens.

### Custom Key Binding

Trigger precedence is:
1. If `@which-key-trigger` is unset or empty, bind `prefix + Space`.
2. If `@which-key-trigger` is one of `None`, `Off`, `Disabled`, `False`, or `0`, do not bind a plugin trigger.
3. Otherwise, bind `prefix + <@which-key-trigger>`.

On reload, the plugin unbinds its previously managed trigger first, so old plugin-managed bindings do not linger.

You can also create your own binding entirely in `~/.tmux.conf`.

To bind `Ctrl-Space` directly (no prefix needed):

```tmux
# Disable the default prefix binding
set -g @which-key-trigger 'None'

# Bind Ctrl-Space directly (-n = no prefix)
bind-key -n C-Space run-shell 'tmux display-popup -E -h 16 -w 100 -x C -y S -S "fg=#4C566A" -s "bg=#2E3440" "~/.tmux/plugins/tmux-which-key/scripts/which-key.sh #{pane_id}"'
```

To use a custom config with a manual binding:

```tmux
bind-key -n C-Space run-shell 'tmux display-popup -E -h 16 -w 100 -x C -y S -S "fg=#4C566A" -s "bg=#2E3440" "~/.tmux/plugins/tmux-which-key/scripts/which-key.sh --config ~/.config/tmux-which-key/config.json #{pane_id}"'
```

To verify active bindings:

```bash
tmux list-keys -T prefix | grep which-key.sh
tmux list-keys -T root | grep which-key.sh
```

### Custom Config File

The plugin looks for a config file in this order:

1. Path set via `@which-key-config` tmux option
2. `$XDG_CONFIG_HOME/tmux-which-key/config.json` (usually `~/.config/tmux-which-key/config.json`)
3. `~/.tmux-which-key.json`
4. Plugin's built-in `configs/default.json`

When `@which-key-config` is set, the value supports:

- absolute paths (`/path/to/config.json`)
- current-user home expansion (`~/...`)
- environment variables (`$HOME/...` and `${HOME}/...`)
- relative paths (resolved against the active pane working directory)

If an environment variable in `@which-key-config` is undefined, the plugin exits with an explicit error.

To create your own config:

```bash
mkdir -p ~/.config/tmux-which-key
cp ~/.tmux/plugins/tmux-which-key/configs/default.json ~/.config/tmux-which-key/config.json
```

Then edit `~/.config/tmux-which-key/config.json` to your liking.

### Config File Format

The config file is a JSON object with a top-level `items` array. Each item has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | yes | Trigger key token. Supports literals, modifiers (`C-*`, `M-*`), and named keys (`Enter`, `Tab`, `Up`, `F1`, etc.) |
| `type` | string | yes | One of: `group`, `action`, `tmux`, `script`, `popup` |
| `description` | string | yes | Label shown in the menu |
| `command` | string | for non-groups | Command to execute |
| `items` | array | for groups | Nested items in this group |
| `immediate` | boolean | no | For `action` type: also press Enter after pasting (default: `false`) |

### Action Types

| Type | Behavior | Example |
|------|----------|---------|
| `group` | Opens a submenu with nested items | Navigate to git commands |
| `action` | Sends text to the active pane (as if typed). With `"immediate": true`, also presses Enter. | `git status` |
| `tmux` | Executes a tmux command directly | `split-window -h` |
| `script` | Runs a shell script via `tmux run-shell` | `~/scripts/my-script.sh` |
| `popup` | Opens command in a temporary `display-popup` at the pane's working directory. Closes on exit or Escape. | `lazygit` |

### Quoting and Escaping

Execution context differs by item type:

- `action`: sends literal text to pane via `tmux send-keys -l` (not shell-evaluated in plugin).
- `tmux`: runs as a tmux command string.
- `popup`: runs as popup shell command.
- `script`: runs through `tmux run-shell`.

Examples:

```json
[
  { "key": "q", "type": "popup", "command": "tmux list-windows -a -F '#S:#I #{window_name}' | less", "description": "Quoted format + pipe" },
  { "key": "m", "type": "tmux", "command": "display-message \"hello world\"", "description": "Double quotes" },
  { "key": "r", "type": "tmux", "command": "source-file ~/.tmux.conf \\; display-message 'reloaded'", "description": "Command separator" },
  { "key": "p", "type": "tmux", "command": "command-prompt -p 'Name:' 'rename-window \"%%\"'", "description": "Prompt placeholder" }
]
```

Troubleshooting:

- If a `popup` item exits immediately, test the command directly in a shell first.
- If a `tmux` item appears to no-op, check quoting around `\\;` and format strings (`#{...}`).
- Use `tmux show-messages` to inspect errors returned by tmux commands.

### Modifier Keys (`C-` / `M-`)

You can use tmux-style modifier tokens in `key` values:

- `C-x` for Ctrl+`x`
- `M-x` for Meta/Alt+`x`
- `C-Space` and `M-Space`

Example:

```json
{
  "items": [
    { "key": "C-s", "type": "tmux", "command": "split-window -v", "description": "Split (Ctrl-s)" },
    { "key": "M-x", "type": "tmux", "command": "kill-pane", "description": "Kill pane (Meta-x)" }
  ]
}
```

Notes:

- Modifier support is best-effort and depends on terminal/tmux key transport.
- Shift-prefixed tokens (`S-*`) are not supported.
- Unsupported tokens are ignored for matching and show a warning message once when used.

### Named Special Keys

Supported named keys:

- `Enter`, `Tab`, `BTab`, `BSpace`, `Escape`
- `Up`, `Down`, `Left`, `Right`
- `Home`, `End`, `PageUp`, `PageDown`, `Delete`, `Insert`
- `F1` through `F12`

Examples:

```json
{
  "items": [
    { "key": "Enter", "type": "tmux", "command": "confirm-before -p 'Run?' 'display-message done'", "description": "Confirm" },
    { "key": "Up", "type": "tmux", "command": "select-pane -U", "description": "Pane up" },
    { "key": "F2", "type": "tmux", "command": "rename-window", "description": "Rename window" },
    { "key": "M-Enter", "type": "tmux", "command": "split-window -v", "description": "Meta Enter split" }
  ]
}
```

Ambiguity policy:

- `Tab` matches `Tab` and `C-i`
- `Enter` matches `Enter`, `C-m`, and `C-j`
- `Escape` matches `Escape` and `C-[`

Navigation fallback:

- Plain `Escape` still closes/backs out when there is no matching `Escape` entry in the current menu.
- `BSpace` still goes back when there is no matching `BSpace` entry in the current menu.

### Example Config

```json
{
  "items": [
    {
      "key": "g",
      "type": "group",
      "description": "git",
      "items": [
        { "key": "s", "type": "action", "command": "git status", "description": "Status", "immediate": true },
        { "key": "c", "type": "action", "command": "git commit", "description": "Commit" },
        { "key": "g", "type": "popup", "command": "lazygit", "description": "Lazygit" }
      ]
    },
    {
      "key": "w",
      "type": "group",
      "description": "window",
      "items": [
        { "key": "v", "type": "tmux", "command": "split-window -h -c '#{pane_current_path}'", "description": "Split vertical" },
        { "key": "s", "type": "tmux", "command": "split-window -v -c '#{pane_current_path}'", "description": "Split horizontal" }
      ]
    },
    { "key": "r", "type": "tmux", "command": "source-file ~/.tmux.conf \\; display-message 'Config reloaded'", "description": "Reload config" },
    { "key": "h", "type": "popup", "command": "htop", "description": "System monitor" },
    { "key": "d", "type": "script", "command": "~/scripts/deploy.sh", "description": "Deploy" }
  ]
}
```

## Default Keybindings

The built-in default config provides ~75 commands organized into 8 groups plus standalone items. Press `prefix + Space` to open the root menu:

### Root Menu

| Key | Type | Description |
|-----|------|-------------|
| `p` | group | **Pane** - split, navigate, zoom, swap, resize, and more |
| `w` | group | **Window** - create, kill, rename, find, navigate, move |
| `s` | group | **Session** - create, detach, choose, rename, kill, switch |
| `b` | group | **Buffer** - list, paste, choose, save/load, copy mode |
| `l` | group | **Layout** - cycle layouts and select presets |
| `C` | group | **Client** - list, choose, detach, refresh, lock |
| `o` | group | **Options** - show/set options, environment, messages |
| `g` | group | **Git** - status, diff, log, push, pull, branches, fetch, add, commit, rebase |
| `:` | tmux | Command prompt |
| `r` | tmux | Reload tmux config |
| `?` | tmux | List all keybindings |
| `c` | action | Clear screen |
| `t` | tmux | Clock mode |
| `d` | tmux | Display panes |

### Pane (`p`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `v` | Split vertical | `s` | Split horizontal |
| `h/j/k/l` | Navigate panes | `z` | Zoom toggle |
| `x` | Kill pane | `o` | Last pane |
| `!` | Break to window | `J` | Join pane |
| `m/M` | Mark/unmark pane | `{/}` | Swap up/down |
| `c` | Clear history | `q` | Capture to buffer |
| `p` | Respawn pane | `r` | **+Resize** (subgroup) |

### Window (`w`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `n` | New window | `x` | Kill window |
| `r` | Rename | `f` | Find window |
| `l` | Last window | `.` | Next window |
| `,` | Previous window | `w` | Choose window |
| `m` | Move window | `s` | Swap window |
| `R` | Rotate panes | | |

### Session (`s`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `n` | New session | `d` | Detach |
| `s` | Choose session | `w` | Choose tree |
| `r` | Rename | `k` | Kill session |
| `l` | List sessions | `L` | Lock session |
| `(` | Previous session | `)` | Next session |

### Buffer (`b`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `l` | List buffers | `p` | Paste |
| `c` | Choose buffer | `d` | Delete buffer |
| `s` | Save to file | `L` | Load from file |
| `v` | Show buffer | `y` | Copy mode |
| `C` | Capture pane | | |

### Layout (`l`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `n` | Next layout | `p` | Previous layout |
| `1` | Even horizontal | `2` | Even vertical |
| `3` | Main horizontal | `4` | Main vertical |
| `5` | Tiled | | |

### Client (`C`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `l` | List clients | `c` | Choose client |
| `d` | Detach | `D` | Detach other |
| `r` | Refresh | `s` | Suspend |
| `L` | Lock | | |

### Options (`o`)

| Key | Description | Key | Description |
|-----|-------------|-----|-------------|
| `g` | Show global options | `w` | Show window options |
| `e` | Show environment | `s` | Set global option |
| `c` | Customize mode | `m` | Show messages |
| `k` | List commands | | |

## License

MIT
