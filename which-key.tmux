#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key popup for tmux
# Plugin entry point (sourced by TPM)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option")
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

main() {
    local trigger
    trigger=$(tmux show-option -gqv "@which-key-trigger")
    if [[ -z "$trigger" ]]; then
        trigger="Space"
    fi

    local previous_trigger
    previous_trigger=$(tmux show-option -gqv "@which-key-trigger-bound")
    if [[ -n "$previous_trigger" ]]; then
        tmux unbind-key "$previous_trigger" 2>/dev/null || true
    fi

    local trigger_norm
    trigger_norm=$(printf '%s' "$trigger" | tr '[:upper:]' '[:lower:]')
    case "$trigger_norm" in
        none|off|disabled|false|0)
            tmux set-option -gq "@which-key-trigger-bound" ""
            return 0
            ;;
    esac

    local config
    config=$(get_tmux_option "@which-key-config" "")

    local popup_height
    popup_height=$(get_tmux_option "@which-key-popup-height" "16")

    local popup_width
    popup_width=$(get_tmux_option "@which-key-popup-width" "100")

    local popup_bg
    popup_bg=$(get_tmux_option "@which-key-popup-bg" "#2E3440")

    local popup_fg
    popup_fg=$(get_tmux_option "@which-key-popup-fg" "#4C566A")

    local popup_x
    popup_x=$(get_tmux_option "@which-key-popup-x" "C")

    local popup_y
    popup_y=$(get_tmux_option "@which-key-popup-y" "S")

    local color_key
    color_key=$(get_tmux_option "@which-key-color-key" "#EBCB8B")

    local color_group
    color_group=$(get_tmux_option "@which-key-color-group" "#88C0D0")

    local color_desc
    color_desc=$(get_tmux_option "@which-key-color-desc" "#D8DEE9")

    local color_separator
    color_separator=$(get_tmux_option "@which-key-color-separator" "#4C566A")

    local color_header
    color_header=$(get_tmux_option "@which-key-color-header" "#81A1C1")

    local color_key_q color_group_q color_desc_q color_separator_q color_header_q
    color_key_q=$(printf '%q' "$color_key")
    color_group_q=$(printf '%q' "$color_group")
    color_desc_q=$(printf '%q' "$color_desc")
    color_separator_q=$(printf '%q' "$color_separator")
    color_header_q=$(printf '%q' "$color_header")

    # Build script invocation with shell-safe quoting
    local script_invocation
    local config_q=""
    if [[ -n "$config" ]]; then
        config_q=$(printf '%q' "$config")
    fi

    local script_path_q
    script_path_q=$(printf '%q' "$CURRENT_DIR/scripts/which-key.sh")
    script_invocation="$script_path_q"
    if [[ -n "$config_q" ]]; then
        script_invocation+=" --config $config_q"
    fi
    script_invocation+=" #{pane_id}"

    # Build popup command
    local popup_cmd="tmux display-popup -E"
    popup_cmd+=" -h $popup_height -w $popup_width"
    popup_cmd+=" -x $popup_x -y $popup_y"
    popup_cmd+=" -S 'fg=$popup_fg' -s 'bg=$popup_bg'"
    popup_cmd+=" -e WHICH_KEY_COLOR_KEY=$color_key_q"
    popup_cmd+=" -e WHICH_KEY_COLOR_GROUP=$color_group_q"
    popup_cmd+=" -e WHICH_KEY_COLOR_DESC=$color_desc_q"
    popup_cmd+=" -e WHICH_KEY_COLOR_SEPARATOR=$color_separator_q"
    popup_cmd+=" -e WHICH_KEY_COLOR_HEADER=$color_header_q"
    popup_cmd+=" $script_invocation"

    tmux bind-key "$trigger" run-shell "$popup_cmd"
    tmux set-option -gq "@which-key-trigger-bound" "$trigger"
}

main
