#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../scripts/lib/read-key.sh
source "$ROOT_DIR/scripts/lib/read-key.sh"

export WK_ESC_POLL_INTERVAL=0.002
export WK_ESC_POLL_ATTEMPTS=8
export WK_ESC_DRAIN_ATTEMPTS=4

to_hex() {
    od -An -t x1 | tr -d ' \n'
}

run_case() {
    local label="$1"
    local input="$2"
    local expected="$3"
    local actual

    actual="$(printf '%b' "$input" | read_keypress | to_hex)"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: $label (expected $expected got $actual)"
        return 1
    fi

    echo "PASS: $label"
}

run_case "regular key" "a" "61"
run_case "plain escape" "\\e" "1b"
run_case "arrow sequence" "\\e[A" "1b5b41"
run_case "csi sequence" "\\e[1;5C" "1b5b313b3543"

echo "All read_keypress checks passed."
