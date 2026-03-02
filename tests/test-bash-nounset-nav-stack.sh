#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/which-key.sh"
CONFIG="$ROOT_DIR/configs/default.json"

make_stub_path() {
    local bin_dir="$1/bin"
    mkdir -p "$bin_dir"

    cat > "$bin_dir/clear" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat > "$bin_dir/tmux" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    chmod +x "$bin_dir/clear" "$bin_dir/tmux"
    printf "%s" "$bin_dir"
}

run_case() {
    local shell_bin="$1"
    local label="$2"
    local keystrokes="$3"

    local tmpdir
    tmpdir="$(mktemp -d)"
    local stub_bin
    stub_bin="$(make_stub_path "$tmpdir")"

    if ! printf "%b" "$keystrokes" | PATH="$stub_bin:$PATH" "$shell_bin" "$SCRIPT" --config "$CONFIG" "%1" >/dev/null 2>&1; then
        echo "FAIL: $label ($shell_bin) exited non-zero"
        rm -rf "$tmpdir"
        return 1
    fi

    rm -rf "$tmpdir"
    echo "PASS: $label ($shell_bin)"
}

detect_bash_major() {
    local shell_bin="$1"
    "$shell_bin" -c 'printf "%s" "${BASH_VERSINFO[0]}"'
}

run_for_shell() {
    local shell_bin="$1"
    local major
    major="$(detect_bash_major "$shell_bin")"
    echo "Testing $shell_bin (bash $major)"

    run_case "$shell_bin" "esc closes from empty root stack" '\e'
    run_case "$shell_bin" "backspace closes from empty root stack" '\177'
    # Enter first group then step back twice (back then close) using Backspace.
    run_case "$shell_bin" "backspace pops non-empty stack safely" 'p\177\177'
}

run_for_shell /bin/bash
modern_ran=0

if command -v bash >/dev/null 2>&1; then
    system_bash="$(command -v bash)"
    if [[ "$system_bash" != "/bin/bash" ]]; then
        major="$(detect_bash_major "$system_bash")"
        if [[ "$major" -ge 5 ]]; then
            run_for_shell "$system_bash"
            modern_ran=1
        else
            echo "SKIP: $system_bash is bash $major (<5)"
        fi
    fi
fi

for candidate in /usr/local/bin/bash /opt/homebrew/bin/bash; do
    if [[ "$modern_ran" -eq 1 ]]; then
        break
    fi
    if [[ -x "$candidate" ]]; then
        major="$(detect_bash_major "$candidate")"
        if [[ "$major" -ge 5 ]]; then
            run_for_shell "$candidate"
            modern_ran=1
            break
        fi
    fi
done
