#!/usr/bin/env bash

wk_max_items_per_menu() {
    local config_file="$1"
    jq -r '[.. | objects | select(has("items") and (.items | type == "array")) | .items | length] | max // 0' "$config_file" 2>/dev/null
}

wk_compute_menu_rows() {
    local items="$1"
    local cols="${2:-$WK_MENU_NUM_COLS}"

    [[ "$items" =~ ^[0-9]+$ ]] || items=0
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=$WK_MENU_NUM_COLS
    if ((cols < 1)); then
        cols=1
    fi

    printf '%s\n' "$(( (items + cols - 1) / cols ))"
}

wk_compute_effective_popup_height() {
    local min_height="$1"
    local config_file="$2"
    local client_height="$3"
    local max_items max_rows required_inner_height required_outer_height effective cap

    [[ "$min_height" =~ ^[0-9]+$ ]] || min_height=16

    max_items=$(wk_max_items_per_menu "$config_file")
    [[ "$max_items" =~ ^[0-9]+$ ]] || max_items=0

    max_rows=$(wk_compute_menu_rows "$max_items" "$WK_MENU_NUM_COLS")
    required_inner_height=$((max_rows + WK_MENU_CHROME_LINES))
    required_outer_height=$((required_inner_height + WK_POPUP_BORDER_LINES))

    effective=$min_height
    if ((required_outer_height > effective)); then
        effective=$required_outer_height
    fi

    if [[ "$client_height" =~ ^[0-9]+$ ]] && ((client_height > WK_POPUP_BORDER_LINES)); then
        cap=$((client_height - WK_POPUP_BORDER_LINES))
        if ((effective > cap)); then
            effective=$cap
        fi
    fi

    if ((effective < WK_POPUP_MIN_HEIGHT)); then
        effective=$WK_POPUP_MIN_HEIGHT
    fi

    printf '%s\n' "$effective"
}

wk_popup_content_height() {
    local popup_height="$1"
    local inner_height

    [[ "$popup_height" =~ ^[0-9]+$ ]] || return 1
    inner_height=$((popup_height - WK_POPUP_BORDER_LINES))
    if ((inner_height < 1)); then
        inner_height=1
    fi
    printf '%s\n' "$inner_height"
}
