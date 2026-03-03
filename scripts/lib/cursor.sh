#!/usr/bin/env bash

wk_hide_cursor() {
    printf '\033[?25l'
}

wk_show_cursor() {
    printf '\033[?25h'
}

wk_move_cursor_to_row() {
    local row="${1:-1}"
    if ! [[ "$row" =~ ^[0-9]+$ ]] || ((row < 1)); then
        row=1
    fi
    printf '\033[%s;1H' "$row"
}

wk_cleanup_ui() {
    local color_reset="$1"
    wk_show_cursor
    printf "%s" "$color_reset"
}
