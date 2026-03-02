#!/usr/bin/env bash

# Read one logical keypress from stdin.
# Returns a single byte for regular keys and plain Escape, or a full
# multi-byte escape sequence (for example arrow keys) when present.
read_keypress() {
    local esc_poll_interval="${WK_ESC_POLL_INTERVAL:-0.01}"
    local esc_poll_attempts="${WK_ESC_POLL_ATTEMPTS:-4}"
    local esc_drain_attempts="${WK_ESC_DRAIN_ATTEMPTS:-2}"
    local keypress=""
    local seq=""
    local seq1=""
    local i=0
    local drain_misses=0

    IFS= read -rsn1 keypress || return 1

    if [[ "$keypress" != $'\x1b' ]]; then
        printf '%s' "$keypress"
        return 0
    fi

    # Non-interactive stdin (pipes/tests): consume what is available until EOF.
    if [[ ! -t 0 ]]; then
        seq1=""
        if IFS= read -rsn1 seq1; then
            seq+="$seq1"
            while IFS= read -rsn1 seq1; do
                seq+="$seq1"
                [[ ${#seq} -ge 16 ]] && break
            done
            printf '%s%s' "$keypress" "$seq"
            return 0
        fi

        printf '%s' "$keypress"
        return 0
    fi

    # Interactive tty: use nonblocking reads with short polling to avoid
    # fractional read -t, which is not supported consistently in older Bash.
    while (( i < esc_poll_attempts )); do
        seq1=""
        if IFS= read -rsn1 -t 0 seq1; then
            seq+="$seq1"
            break
        fi
        sleep "$esc_poll_interval"
        ((i++))
    done

    if [[ -z "$seq" ]]; then
        printf '%s' "$keypress"
        return 0
    fi

    while :; do
        seq1=""
        if IFS= read -rsn1 -t 0 seq1; then
            seq+="$seq1"
            drain_misses=0
            [[ ${#seq} -ge 16 ]] && break
            continue
        fi

        ((drain_misses++))
        (( drain_misses >= esc_drain_attempts )) && break
        sleep "$esc_poll_interval"
    done

    printf '%s%s' "$keypress" "$seq"
}
