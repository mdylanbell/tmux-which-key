#!/usr/bin/env bash

wk_expand_env_refs() {
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
                echo "Unsupported variable expression in config path: $input" >&2
                return 1
            fi
            output+="$rest"
            break
        fi

        if [[ -z ${!var_name+x} ]]; then
            echo "Undefined environment variable in config path: $var_name" >&2
            return 1
        fi
        output+="${!var_name}"
    done

    printf '%s\n' "$output"
}

wk_apply_home_expansion() {
    local value="$1"

    case "$value" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s\n' "$HOME/${value#~/}"
            ;;
        *)
            printf '%s\n' "$value"
            ;;
    esac
}

wk_resolve_config_path() {
    local raw="$1"
    local relative_base="$2"
    local expanded

    expanded=$(wk_expand_env_refs "$raw") || return 1
    expanded=$(wk_apply_home_expansion "$expanded")

    if [[ "$expanded" != /* ]]; then
        expanded="$relative_base/$expanded"
    fi

    printf '%s\n' "$expanded"
}

wk_default_config_file() {
    local plugin_dir="$1"
    local candidate

    candidate="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-which-key/config.json"
    if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$HOME/.tmux-which-key.json"
    if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$plugin_dir/configs/default.json"
    printf '%s\n' "$candidate"
}
