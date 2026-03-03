#!/usr/bin/env bash

# Shared UI/layout constants.
WK_MENU_NUM_COLS=3
WK_MENU_CHROME_LINES=5
WK_MENU_SEPARATOR_WIDTH=98
WK_POPUP_BORDER_LINES=2
WK_POPUP_MIN_HEIGHT=6

wk_is_truthy_option() {
    local value="$1"
    local default_value="$2"
    local normalized

    if [[ -z "$value" ]]; then
        value="$default_value"
    fi

    normalized=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    case "$normalized" in
        1|on|true|yes)
            return 0
            ;;
    esac
    return 1
}
