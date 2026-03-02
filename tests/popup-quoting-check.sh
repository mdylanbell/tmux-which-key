#!/usr/bin/env bash

set -euo pipefail

shell_escape() {
    printf "%q" "$1"
}

build_popup_run_shell_command() {
    local pane_path="$1"
    local command="$2"
    local escaped_path escaped_command

    escaped_path=$(shell_escape "$pane_path")
    escaped_command=$(shell_escape "$command")

    printf "sleep 0.1 && tmux display-popup -E -h 80%% -w 80%% -d %s %s" "$escaped_path" "$escaped_command"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"

    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $label"
        echo "expected: $expected"
        echo "actual:   $actual"
        exit 1
    fi
}

run_case() {
    local pane_path="$1"
    local command="$2"
    local label="$3"
    local built_cmd
    local -a tmux_args=()

    built_cmd=$(build_popup_run_shell_command "$pane_path" "$command")

    sleep() { :; }
    tmux() { tmux_args=("$@"); }

    eval "$built_cmd"

    assert_eq "display-popup" "${tmux_args[0]:-}" "$label: subcommand"
    assert_eq "-E" "${tmux_args[1]:-}" "$label: popup mode"
    assert_eq "-h" "${tmux_args[2]:-}" "$label: height flag"
    assert_eq "80%" "${tmux_args[3]:-}" "$label: height value"
    assert_eq "-w" "${tmux_args[4]:-}" "$label: width flag"
    assert_eq "80%" "${tmux_args[5]:-}" "$label: width value"
    assert_eq "-d" "${tmux_args[6]:-}" "$label: cwd flag"
    assert_eq "$pane_path" "${tmux_args[7]:-}" "$label: pane path"
    assert_eq "$command" "${tmux_args[8]:-}" "$label: command payload"
}

run_case "/tmp/project" "lazygit" "simple command"
run_case "/tmp/it's-here" "printf '%s\n' \"it's fine\"" "single quote command"
run_case "/tmp/project" "echo '#{pane_current_path}' | sed 's/x/y/'" "tmux format and pipeline"

echo "popup quoting check passed"
