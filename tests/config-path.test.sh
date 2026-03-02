#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/config-path.sh"

fail() {
    echo "FAIL: $1"
    exit 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    [[ "$actual" == "$expected" ]] || fail "$msg (expected: $expected, got: $actual)"
}

base="/tmp/pane"
export HOME="/home/testuser"
export CFG_DIR="/etc/tmux"

abs="$(resolve_config_path "/opt/config.json" "$base")"
assert_eq "$abs" "/opt/config.json" "absolute path should remain unchanged"

tilde_home="$(resolve_config_path "~" "$base")"
assert_eq "$tilde_home" "/home/testuser" "tilde home should expand"

# shellcheck disable=SC2088
tilde_input='~/.config/tmux-which-key/config.json'
tilde_file="$(resolve_config_path "$tilde_input" "$base")"
assert_eq "$tilde_file" "/home/testuser/.config/tmux-which-key/config.json" "tilde file should expand"

env_plain="$(resolve_config_path "$CFG_DIR/config.json" "$base")"
assert_eq "$env_plain" "/etc/tmux/config.json" "plain env var should expand"

env_braced="$(resolve_config_path "\${CFG_DIR}/config.json" "$base")"
assert_eq "$env_braced" "/etc/tmux/config.json" "braced env var should expand"

rel="$(resolve_config_path "configs/custom.json" "$base")"
assert_eq "$rel" "/tmp/pane/configs/custom.json" "relative path should resolve against pane cwd"

if resolve_config_path "\$MISSING_VAR/config.json" "$base" >/dev/null 2>&1; then
    fail "undefined env var should fail"
fi

echo "config path resolution tests passed"
