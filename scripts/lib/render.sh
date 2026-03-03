#!/usr/bin/env bash

wk_render_separator() {
    local color_sep="$1"
    local color_reset="$2"
    local width="${3:-$WK_MENU_SEPARATOR_WIDTH}"

    printf "%s" "$color_sep"
    printf '%*s' "$width" '' | tr ' ' '─'
    printf "%s\n" "$color_reset"
}

wk_render_header() {
    local breadcrumb="$1"
    local color_header="$2"
    local color_reset="$3"
    local color_sep="$4"
    local color_desc="$5"

    printf "%s  Which Key%s  %s│%s  %s%s%s\n" "$color_header" "$color_reset" "$color_sep" "$color_reset" "$color_desc" "$breadcrumb" "$color_reset"
    wk_render_separator "$color_sep" "$color_reset"
}

wk_compute_footer_hint() {
    local has_nav="$1"

    if [[ "$has_nav" == "true" ]]; then
        printf '%s\n' "esc  close    ⌫  back"
    else
        printf '%s\n' "esc  close"
    fi
}

wk_render_footer() {
    local has_nav="$1"
    local color_sep="$2"
    local color_reset="$3"

    local hint
    hint=$(wk_compute_footer_hint "$has_nav")

    printf "\n"
    wk_render_separator "$color_sep" "$color_reset"
    printf "  %s%s%s" "$color_sep" "$hint" "$color_reset"
}

wk_print_blank_lines() {
    local lines="$1"
    local i
    for ((i = 0; i < lines; i++)); do
        printf "\n"
    done
}
