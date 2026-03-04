#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key popup for tmux
# Usage: which-key.sh [--config <path>] <pane_id>

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$PLUGIN_DIR/scripts/lib"
CONFIG_FILE=""
PANE_ID=""

load_lib() {
    local file="$1"
    if [[ ! -f "$LIB_DIR/$file" ]]; then
        echo "tmux-which-key: missing library $LIB_DIR/$file" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$LIB_DIR/$file"
}

load_lib "common.sh"
load_lib "config_path.sh"
load_lib "layout.sh"
load_lib "render.sh"
load_lib "cursor.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "Usage: which-key.sh [--config <path>] <pane_id>"
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            PANE_ID="$1"
            shift
            ;;
    esac
done

# Resolve config file: explicit > XDG > user home > plugin default
if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE=$(wk_default_config_file "$PLUGIN_DIR")
else
    pane_path=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}' 2>/dev/null || pwd)
    CONFIG_FILE=$(wk_resolve_existing_config_file_with_base "$CONFIG_FILE" "$PLUGIN_DIR" "$pane_path") || exit 1
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

# Resolve menu token colors from env (set by which-key.tmux), with defaults
C_KEY=$(resolve_color "@which-key-color-key" "${WHICH_KEY_COLOR_KEY:-$DEFAULT_COLOR_KEY}" "$DEFAULT_COLOR_KEY")
C_GRP=$(resolve_color "@which-key-color-group" "${WHICH_KEY_COLOR_GROUP:-$DEFAULT_COLOR_GROUP}" "$DEFAULT_COLOR_GROUP")
C_DESC=$(resolve_color "@which-key-color-desc" "${WHICH_KEY_COLOR_DESC:-$DEFAULT_COLOR_DESC}" "$DEFAULT_COLOR_DESC")
C_BRD=$(resolve_color "@which-key-color-breadcrumb" "${WHICH_KEY_COLOR_BREADCRUMB:-${WHICH_KEY_COLOR_DESC:-$DEFAULT_COLOR_DESC}}" "$DEFAULT_COLOR_DESC")
C_SEP=$(resolve_color "@which-key-color-separator" "${WHICH_KEY_COLOR_SEPARATOR:-$DEFAULT_COLOR_SEPARATOR}" "$DEFAULT_COLOR_SEPARATOR")
C_HDR=$(resolve_color "@which-key-color-header" "${WHICH_KEY_COLOR_HEADER:-$DEFAULT_COLOR_HEADER}" "$DEFAULT_COLOR_HEADER")
BREADCRUMB_SEPARATOR="${WHICH_KEY_BREADCRUMB_SEPARATOR:- > }"
MENU_LAST_ROW=1

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
        tmux display-message "tmux-which-key: unsupported key token '$raw_key'" 2>/dev/null || true
        WARNED_UNSUPPORTED_KEY=1
    fi
}

is_named_key() {
    case "$1" in
        Enter|Tab|BTab|BSpace|Escape|Up|Down|Left|Right|Home|End|PageUp|PageDown|Delete|Insert|F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12)
            return 0
            ;;
    esac
    return 1
}

normalize_config_key() {
    local raw_key="$1"
    local mod
    local base

    if [[ ${#raw_key} -eq 1 ]]; then
        printf '%s\n' "$raw_key"
        return 0
    fi

    if is_named_key "$raw_key"; then
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

        if is_named_key "$base"; then
            printf '%s\n' "${mod}-${base}"
            return 0
        fi
    fi

    warn_unsupported_key "$raw_key"
    return 1
}

decode_escape_sequence() {
    local seq="$1"
    local meta_key

    case "$seq" in
        '[A') printf '%s\n' "Up" ;;
        '[B') printf '%s\n' "Down" ;;
        '[C') printf '%s\n' "Right" ;;
        '[D') printf '%s\n' "Left" ;;
        '[H') printf '%s\n' "Home" ;;
        '[F') printf '%s\n' "End" ;;
        '[Z') printf '%s\n' "BTab" ;;
        '[2~') printf '%s\n' "Insert" ;;
        '[3~') printf '%s\n' "Delete" ;;
        '[5~') printf '%s\n' "PageUp" ;;
        '[6~') printf '%s\n' "PageDown" ;;
        'OP'|'[11~') printf '%s\n' "F1" ;;
        'OQ'|'[12~') printf '%s\n' "F2" ;;
        'OR'|'[13~') printf '%s\n' "F3" ;;
        'OS'|'[14~') printf '%s\n' "F4" ;;
        '[15~') printf '%s\n' "F5" ;;
        '[17~') printf '%s\n' "F6" ;;
        '[18~') printf '%s\n' "F7" ;;
        '[19~') printf '%s\n' "F8" ;;
        '[20~') printf '%s\n' "F9" ;;
        '[21~') printf '%s\n' "F10" ;;
        '[23~') printf '%s\n' "F11" ;;
        '[24~') printf '%s\n' "F12" ;;
        $'\t') printf '%s\n' "M-Tab" ;;
        $'\r'|$'\n') printf '%s\n' "M-Enter" ;;
        $'\x7f'|$'\x08') printf '%s\n' "M-BSpace" ;;
        ' ')
            printf '%s\n' "M-Space"
            ;;
        ?)
            meta_key=$(printf '%s' "$seq" | tr '[:upper:]' '[:lower:]')
            printf '%s\n' "M-$meta_key"
            ;;
        *)
            return 1
            ;;
    esac
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
        $'\x09') printf '%s\n' "Tab" ;;
        $'\x0a') printf '%s\n' "C-j" ;;
        $'\x0b') printf '%s\n' "C-k" ;;
        $'\x0c') printf '%s\n' "C-l" ;;
        $'\x0d') printf '%s\n' "Enter" ;;
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
        $'\x7f') printf '%s\n' "BSpace" ;;
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
    if [[ "$normalized_config" == "$input_key" ]]; then
        return 0
    fi

    case "$normalized_config:$input_key" in
        C-i:Tab|Tab:C-i|C-m:Enter|Enter:C-m|C-[:Escape|Escape:C-[|C-h:BSpace|BSpace:C-h|C-j:Enter|Enter:C-j)
            return 0
            ;;
    esac

    return 1
}

shell_quote() {
    printf '%q' "$1"
}

run_shell_bg() {
    tmux run-shell -b "$1"
}

run_tmux_command() {
    local command="$1"
    local defer="${2:-false}"
    local shell_script

    if [[ "$defer" == "true" ]]; then
        shell_script="sleep 0.1 && tmux $command"
    else
        shell_script="tmux $command"
    fi
    run_shell_bg "$shell_script"
}

get_tmux_subcommand() {
    local command="$1"
    if [[ "$command" =~ ^[[:space:]]*([[:alnum:]-]+) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

is_client_scoped_tmux_command() {
    case "$1" in
        switch-client|detach-client|refresh-client|lock-client)
            return 0
            ;;
    esac
    return 1
}

command_has_explicit_client_target() {
    local command="$1"
    local subcommand="$2"

    case "$subcommand" in
        switch-client)
            [[ "$command" =~ (^|[[:space:]])-c([[:space:]]|$) ]]
            return $?
            ;;
        detach-client|refresh-client|lock-client)
            [[ "$command" =~ (^|[[:space:]])-t([[:space:]]|$) ]]
            return $?
            ;;
    esac

    return 1
}

get_invoking_client_name() {
    tmux display-message -t "$PANE_ID" -p '#{client_name}' 2>/dev/null || true
}

inject_client_target() {
    local command="$1"
    local subcommand="$2"
    local client_name="$3"
    local target_flag="-t"

    if [[ "$subcommand" == "switch-client" ]]; then
        target_flag="-c"
    fi

    printf '%s %s %s\n' "$command" "$target_flag" "$client_name"
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
    local result
    for ((n = 0; n < NAV_DEPTH; n++)); do
        idx=${NAV_STACK[$n]}
        parts+=("$(echo "$CONFIG" | jq -r "${path}[${idx}].description")")
        path="${path}[${idx}].items"
    done
    result="${parts[0]}"
    for ((n = 1; n < ${#parts[@]}; n++)); do
        result+="${BREADCRUMB_SEPARATOR}${parts[$n]}"
    done
    echo "$result"
}

render_menu() {
    clear

    local breadcrumb
    breadcrumb=$(get_breadcrumb)
    local popup_height="${WHICH_KEY_POPUP_HEIGHT:-}"
    local pad_lines=0
    local content_rows=0

    # Header
    wk_render_header "$breadcrumb" "$C_HDR" "$C_R" "$C_SEP" "$C_BRD"

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
        content_rows=1
    else
        # Column layout
        local col_width=32
        local num_cols=$WK_MENU_NUM_COLS
        local num_rows=$(( (total + num_cols - 1) / num_cols ))
        content_rows=$num_rows

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
    fi

    if [[ "$popup_height" =~ ^[0-9]+$ ]]; then
        pad_lines=$(wk_compute_footer_padding "$content_rows" "$popup_height")
    fi

    wk_print_blank_lines "$pad_lines"

    # Footer
    if nav_has_items; then
        wk_render_footer "true" "$C_SEP" "$C_R"
    else
        wk_render_footer "false" "$C_SEP" "$C_R"
    fi

    MENU_LAST_ROW=$((content_rows + pad_lines + WK_MENU_CHROME_LINES))
}

cleanup_ui() {
    wk_cleanup_ui "$C_R"
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
                    pane_path_quoted=$(shell_quote "$pane_path")
                    command_quoted=$(shell_quote "$command")
                    run_shell_bg "sleep 0.1 && tmux display-popup -E -h 80% -w 80% -d $pane_path_quoted $command_quoted"
                    exit 0
                    ;;
                tmux)
                    local effective_command="$command"
                    local auto_target_opt
                    local tmux_subcommand
                    local client_name

                    auto_target_opt=$(tmux show-option -gqv "@which-key-tmux-auto-target" 2>/dev/null || true)
                    if wk_is_truthy_option "$auto_target_opt" "on"; then
                        if tmux_subcommand=$(get_tmux_subcommand "$command"); then
                            if is_client_scoped_tmux_command "$tmux_subcommand" && ! command_has_explicit_client_target "$command" "$tmux_subcommand"; then
                                client_name=$(get_invoking_client_name)
                                if [[ -n "$client_name" ]]; then
                                    effective_command=$(inject_client_target "$command" "$tmux_subcommand" "$client_name")
                                fi
                            fi
                        fi
                    fi

                    case "$effective_command" in
                        choose-*|command-prompt*|customize-mode*|copy-mode*)
                            run_tmux_command "$effective_command" true
                            ;;
                        *)
                            run_tmux_command "$effective_command" false
                            ;;
                    esac
                    exit 0
                    ;;
                script)
                    local script_command_quoted
                    script_command_quoted=$(shell_quote "$command")
                    tmux run-shell "$script_command_quoted"
                    exit 0
                    ;;
            esac
        fi
        ((i++))
    done < <(get_current_items)

    return 1
}

# Main loop
trap cleanup_ui EXIT INT TERM

while true; do
    render_menu
    wk_hide_cursor
    wk_move_cursor_to_row "$MENU_LAST_ROW"

    keypress=""
    seq1=""
    seq_rest=""
    escape_seq=""
    decoded_key=""
    IFS= read -rsn1 keypress || true

    # Escape
    if [[ "$keypress" == $'\x1b' ]]; then
        IFS= read -rsn1 -t 0.1 seq1 || true
        if [[ -z "$seq1" ]]; then
            exit 0
        else
            escape_seq="$seq1"
            while IFS= read -rsn1 -t 0.01 seq_rest; do
                escape_seq+="$seq_rest"
            done

            if decoded_key=$(decode_escape_sequence "$escape_seq"); then
                handle_key "$decoded_key" || true
            fi
        fi
        continue
    fi

    # Backspace
    if [[ "$keypress" == $'\x7f' || "$keypress" == $'\x08' ]]; then
        if handle_key "BSpace"; then
            continue
        fi
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
