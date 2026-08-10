#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d /tmp/lant-repl-exit.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

lant_executable="$(cabal list-bin exe:lant)"

run_exit_case() {
  local name="$1"
  local input="$2"
  local root="$test_root/$name"
  local output="$test_root/$name.out"

  {
    sleep 1
    printf '%b' "$input"
  } | timeout 10 script -qefc \
    "env TERM=xterm-256color XDG_CONFIG_HOME=$root/config XDG_DATA_HOME=$root/data XDG_STATE_HOME=$root/state XDG_RUNTIME_DIR=$root/runtime $lant_executable" \
    /dev/null >"$output"
}

run_exit_case q q
run_exit_case escape '\033'
