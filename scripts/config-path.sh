#!/usr/bin/env bash

# Expand @which-key-config values from tmux option context.
# Supported:
# - absolute paths (/...)
# - current-user home expansion (~ or ~/...)
# - env vars ($VAR and ${VAR})
# Relative paths are resolved against the active pane's cwd.

expand_env_vars() {
    local value="$1"
    local output="$value"
    local key replacement

    while [[ "$output" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
        key="${BASH_REMATCH[1]}"
        if [[ -z "${!key+x}" ]]; then
            return 1
        fi
        replacement="${!key}"
        output="${output//\$\{$key\}/$replacement}"
    done

    while [[ "$output" =~ \$([A-Za-z_][A-Za-z0-9_]*) ]]; do
        key="${BASH_REMATCH[1]}"
        if [[ -z "${!key+x}" ]]; then
            return 1
        fi
        replacement="${!key}"
        output="${output//\$$key/$replacement}"
    done

    printf "%s\n" "$output"
}

resolve_config_path() {
    local raw_path="$1"
    local base_dir="$2"
    local resolved="$raw_path"

    if [[ "$resolved" == "~" ]]; then
        resolved="$HOME"
    elif [[ "$resolved" == \~/* ]]; then
        resolved="$HOME/${resolved:2}"
    fi

    if [[ "$resolved" == *'$'* ]]; then
        if ! resolved="$(expand_env_vars "$resolved")"; then
            return 1
        fi
    fi

    if [[ "$resolved" != /* ]]; then
        resolved="$base_dir/$resolved"
    fi

    printf "%s\n" "$resolved"
}
