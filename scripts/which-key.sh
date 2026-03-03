#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key popup for tmux
# Usage: which-key.sh [--config <path>] <pane_id>

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE=""
PANE_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            PANE_ID="$1"
            shift
            ;;
    esac
done

expand_env_refs() {
    local input="$1"
    local output=""
    local rest="$input"
    local var_name

    while [[ -n "$rest" ]]; do
        if [[ "$rest" =~ ^([^$]*)\$\{([A-Za-z_][A-Za-z0-9_]*)\}(.*)$ ]]; then
            output+="${BASH_REMATCH[1]}"
            var_name="${BASH_REMATCH[2]}"
            rest="${BASH_REMATCH[3]}"
        elif [[ "$rest" =~ ^([^$]*)\$([A-Za-z_][A-Za-z0-9_]*)(.*)$ ]]; then
            output+="${BASH_REMATCH[1]}"
            var_name="${BASH_REMATCH[2]}"
            rest="${BASH_REMATCH[3]}"
        else
            if [[ "$rest" == *'$'* ]]; then
                echo "Unsupported variable expression in config path: $input"
                return 1
            fi
            output+="$rest"
            break
        fi

        if [[ -z ${!var_name+x} ]]; then
            echo "Undefined environment variable in config path: $var_name"
            return 1
        fi
        output+="${!var_name}"
    done

    printf '%s\n' "$output"
}

resolve_config_path() {
    local raw="$1"
    local expanded
    local pane_path

    expanded=$(expand_env_refs "$raw") || return 1

    case "$expanded" in
        "~")
            expanded="$HOME"
            ;;
        "~/"*)
            expanded="$HOME/${expanded#~/}"
            ;;
    esac

    if [[ "$expanded" != /* ]]; then
        pane_path=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}' 2>/dev/null || pwd)
        expanded="$pane_path/$expanded"
    fi

    printf '%s\n' "$expanded"
}

# Resolve config file: explicit > XDG > user home > plugin default
if [[ -z "$CONFIG_FILE" ]]; then
    local_xdg="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-which-key/config.json"
    local_home="$HOME/.tmux-which-key.json"
    if [[ -f "$local_xdg" ]]; then
        CONFIG_FILE="$local_xdg"
    elif [[ -f "$local_home" ]]; then
        CONFIG_FILE="$local_home"
    else
        CONFIG_FILE="$PLUGIN_DIR/configs/default.json"
    fi
else
    CONFIG_FILE=$(resolve_config_path "$CONFIG_FILE") || exit 1
fi

DEFAULT_COLOR_KEY="#EBCB8B"
DEFAULT_COLOR_GROUP="#88C0D0"
DEFAULT_COLOR_DESC="#D8DEE9"
DEFAULT_COLOR_SEPARATOR="#4C566A"
DEFAULT_COLOR_HEADER="#81A1C1"
C_R=$'\033[0m'

WARNED_INVALID_COLOR=0

is_hex_color() {
    [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]
}

hex_to_ansi_fg() {
    local hex="${1#\#}"
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

warn_invalid_color() {
    local option_name="$1"
    local option_value="$2"

    if ((WARNED_INVALID_COLOR == 0)); then
        tmux display-message "tmux-which-key: invalid color for $option_name ($option_value), using defaults" 2>/dev/null || true
        WARNED_INVALID_COLOR=1
    fi
}

resolve_color() {
    local option_name="$1"
    local value="$2"
    local fallback_hex="$3"

    if is_hex_color "$value"; then
        hex_to_ansi_fg "$value"
        return 0
    fi

    warn_invalid_color "$option_name" "$value"
    hex_to_ansi_fg "$fallback_hex"
}

if [[ -z "$PANE_ID" ]]; then
    echo "Usage: which-key.sh [--config <path>] <pane_id>"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

# Resolve menu token colors from env (set by which-key.tmux), with defaults
C_KEY=$(resolve_color "@which-key-color-key" "${WHICH_KEY_COLOR_KEY:-$DEFAULT_COLOR_KEY}" "$DEFAULT_COLOR_KEY")
C_GRP=$(resolve_color "@which-key-color-group" "${WHICH_KEY_COLOR_GROUP:-$DEFAULT_COLOR_GROUP}" "$DEFAULT_COLOR_GROUP")
C_DESC=$(resolve_color "@which-key-color-desc" "${WHICH_KEY_COLOR_DESC:-$DEFAULT_COLOR_DESC}" "$DEFAULT_COLOR_DESC")
C_SEP=$(resolve_color "@which-key-color-separator" "${WHICH_KEY_COLOR_SEPARATOR:-$DEFAULT_COLOR_SEPARATOR}" "$DEFAULT_COLOR_SEPARATOR")
C_HDR=$(resolve_color "@which-key-color-header" "${WHICH_KEY_COLOR_HEADER:-$DEFAULT_COLOR_HEADER}" "$DEFAULT_COLOR_HEADER")

# Read entire config into memory once
CONFIG=$(cat "$CONFIG_FILE")

# Navigation stack (jq path indices)
NAV_STACK=()
NAV_DEPTH=0

nav_push() {
    NAV_STACK[$NAV_DEPTH]="$1"
    ((NAV_DEPTH++))
}

nav_pop() {
    if ((NAV_DEPTH > 0)); then
        ((NAV_DEPTH--))
        unset "NAV_STACK[$NAV_DEPTH]"
        return 0
    fi
    return 1
}

nav_has_items() {
    ((NAV_DEPTH > 0))
}

WARNED_UNSUPPORTED_KEY=0

warn_unsupported_key() {
    local raw_key="$1"

    if ((WARNED_UNSUPPORTED_KEY == 0)); then
        tmux display-message "tmux-which-key: unsupported key token '$raw_key' (expected literal, C-<char>, M-<char>, or *-Space)" 2>/dev/null || true
        WARNED_UNSUPPORTED_KEY=1
    fi
}

normalize_config_key() {
    local raw_key="$1"
    local mod
    local base

    if [[ ${#raw_key} -eq 1 ]]; then
        printf '%s\n' "$raw_key"
        return 0
    fi

    if [[ "$raw_key" =~ ^(C|M)-(.+)$ ]]; then
        mod="${BASH_REMATCH[1]}"
        base="${BASH_REMATCH[2]}"

        if [[ "$base" == "Space" ]]; then
            printf '%s\n' "${mod}-Space"
            return 0
        fi

        if [[ ${#base} -eq 1 ]]; then
            base=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
            printf '%s\n' "${mod}-${base}"
            return 0
        fi
    fi

    warn_unsupported_key "$raw_key"
    return 1
}

normalize_input_key() {
    local key="$1"

    case "$key" in
        $'\x00') printf '%s\n' "C-Space" ;;
        $'\x01') printf '%s\n' "C-a" ;;
        $'\x02') printf '%s\n' "C-b" ;;
        $'\x03') printf '%s\n' "C-c" ;;
        $'\x04') printf '%s\n' "C-d" ;;
        $'\x05') printf '%s\n' "C-e" ;;
        $'\x06') printf '%s\n' "C-f" ;;
        $'\x07') printf '%s\n' "C-g" ;;
        $'\x08') printf '%s\n' "C-h" ;;
        $'\x09') printf '%s\n' "C-i" ;;
        $'\x0a') printf '%s\n' "C-j" ;;
        $'\x0b') printf '%s\n' "C-k" ;;
        $'\x0c') printf '%s\n' "C-l" ;;
        $'\x0d') printf '%s\n' "C-m" ;;
        $'\x0e') printf '%s\n' "C-n" ;;
        $'\x0f') printf '%s\n' "C-o" ;;
        $'\x10') printf '%s\n' "C-p" ;;
        $'\x11') printf '%s\n' "C-q" ;;
        $'\x12') printf '%s\n' "C-r" ;;
        $'\x13') printf '%s\n' "C-s" ;;
        $'\x14') printf '%s\n' "C-t" ;;
        $'\x15') printf '%s\n' "C-u" ;;
        $'\x16') printf '%s\n' "C-v" ;;
        $'\x17') printf '%s\n' "C-w" ;;
        $'\x18') printf '%s\n' "C-x" ;;
        $'\x19') printf '%s\n' "C-y" ;;
        $'\x1a') printf '%s\n' "C-z" ;;
        $'\x1c') printf '%s\n' "C-\\" ;;
        $'\x1d') printf '%s\n' "C-]" ;;
        $'\x1e') printf '%s\n' "C-^" ;;
        $'\x1f') printf '%s\n' "C-_" ;;
        *)
            printf '%s\n' "$key"
            ;;
    esac
}

keys_match() {
    local config_key="$1"
    local input_key="$2"
    local normalized_config

    normalized_config=$(normalize_config_key "$config_key") || return 1
    [[ "$normalized_config" == "$input_key" ]]
}

# Get current items as tab-separated lines: key\ttype\tdescription\tcommand\timmediate
# Single jq call per menu level instead of per-item
get_current_items() {
    local path=".items"
    local n idx
    for ((n = 0; n < NAV_DEPTH; n++)); do
        idx=${NAV_STACK[$n]}
        path="${path}[${idx}].items"
    done
    echo "$CONFIG" | jq -r "${path}[] | [.key, .type, .description, (.command // \"\"), (if .immediate then \"true\" else \"false\" end)] | @tsv" 2>/dev/null
}

get_breadcrumb() {
    local path=".items"
    local parts=("root")
    local n idx
    for ((n = 0; n < NAV_DEPTH; n++)); do
        idx=${NAV_STACK[$n]}
        parts+=("$(echo "$CONFIG" | jq -r "${path}[${idx}].description")")
        path="${path}[${idx}].items"
    done
    local IFS=" > "
    echo "${parts[*]}"
}

render_menu() {
    clear

    local breadcrumb
    breadcrumb=$(get_breadcrumb)

    # Header
    printf "%s  Which Key%s  %s│%s  %s%s%s\n" "$C_HDR" "$C_R" "$C_SEP" "$C_R" "$C_DESC" "$breadcrumb" "$C_R"
    printf "%s" "$C_SEP"
    printf '%.0s─' {1..98}
    printf "%s\n" "$C_R"

    # Parse all items in one jq call
    local keys=() types=() descs=()
    while IFS=$'\t' read -r key type desc _cmd; do
        keys+=("$key")
        types+=("$type")
        descs+=("$desc")
    done < <(get_current_items)

    local total=${#keys[@]}
    if [[ $total -eq 0 ]]; then
        printf "  %s(empty)%s\n" "$C_DESC" "$C_R"
        return
    fi

    # Column layout
    local col_width=32
    local num_cols=3
    local num_rows=$(( (total + num_cols - 1) / num_cols ))

    for ((row = 0; row < num_rows; row++)); do
        printf "  "
        for ((col = 0; col < num_cols; col++)); do
            local i=$((col * num_rows + row))
            if [[ $i -lt $total ]]; then
                local k="${keys[$i]}" t="${types[$i]}" d="${descs[$i]}"
                local prefix="" dc="$C_DESC"
                if [[ "$t" == "group" ]]; then
                    prefix="+"
                    dc="$C_GRP"
                fi
                local visible_len=$(( ${#k} + 4 + ${#prefix} + ${#d} ))
                local pad=$((col_width - visible_len))
                [[ $pad -lt 1 ]] && pad=1
                printf "%s%s%s  %s→%s %s%s%s%s" "$C_KEY" "$k" "$C_R" "$C_SEP" "$C_R" "$dc" "$prefix" "$d" "$C_R"
                printf '%*s' "$pad" ""
            fi
        done
        printf "\n"
    done

    # Footer
    printf "\n%s" "$C_SEP"
    printf '%.0s─' {1..98}
    printf "%s\n" "$C_R"
    if nav_has_items; then
        printf "  %sesc  close    ⌫  back%s\n" "$C_SEP" "$C_R"
    else
        printf "  %sesc  close%s\n" "$C_SEP" "$C_R"
    fi
}

handle_key() {
    local input_key="$1"
    local i=0

    while IFS=$'\t' read -r key type desc command immediate; do
        if keys_match "$key" "$input_key"; then
            case "$type" in
                group)
                    nav_push "$i"
                    return 0
                    ;;
                action)
                    tmux send-keys -t "$PANE_ID" -l "$command"
                    if [[ "$immediate" == "true" ]]; then
                        tmux send-keys -t "$PANE_ID" Enter
                    fi
                    exit 0
                    ;;
                popup)
                    local pane_path
                    local pane_path_quoted
                    local command_quoted
                    pane_path=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}')
                    pane_path_quoted=$(printf '%q' "$pane_path")
                    command_quoted=$(printf '%q' "$command")
                    tmux run-shell -b "sleep 0.1 && tmux display-popup -E -h 80% -w 80% -d $pane_path_quoted $command_quoted"
                    exit 0
                    ;;
                tmux)
                    case "$command" in
                        choose-*|command-prompt*|customize-mode*|copy-mode*)
                            tmux run-shell -b "sleep 0.1 && tmux $command"
                            ;;
                        *)
                            tmux $command
                            ;;
                    esac
                    exit 0
                    ;;
                script)
                    tmux run-shell "$command"
                    exit 0
                    ;;
            esac
        fi
        ((i++))
    done < <(get_current_items)
}

# Main loop
while true; do
    render_menu

    keypress=""
    IFS= read -rsn1 keypress || true

    # Escape
    if [[ "$keypress" == $'\x1b' ]]; then
        seq1=""
        IFS= read -rsn1 -t 0.1 seq1 || true
        if [[ -z "$seq1" ]]; then
            if ! nav_pop; then
                exit 0
            fi
        elif [[ ${#seq1} -eq 1 ]]; then
            meta_key=$(printf '%s' "$seq1" | tr '[:upper:]' '[:lower:]')
            handle_key "M-$meta_key"
        fi
        continue
    fi

    # Backspace
    if [[ "$keypress" == $'\x7f' || "$keypress" == $'\x08' ]]; then
        if ! nav_pop; then
            exit 0
        fi
        continue
    fi

    # Regular key
    if [[ -n "$keypress" ]]; then
        normalized_key=$(normalize_input_key "$keypress")
        handle_key "$normalized_key"
    fi
done
