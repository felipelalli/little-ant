#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d /tmp/lant-s01-cli.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

lant_executable="$(cabal list-bin exe:lant)"
pack_runner_executable="$(cabal list-bin exe:lant-pack-runner)"
pack_runner_directory="$(dirname "$pack_runner_executable")"
profile_root="$test_root/profile"
state_home="$profile_root/state"

lant_at() {
  local root="$1"
  shift
  XDG_CONFIG_HOME="$root/config" \
    XDG_DATA_HOME="$root/data" \
    XDG_STATE_HOME="$root/state" \
    XDG_RUNTIME_DIR="$root/runtime" \
    PATH="$pack_runner_directory:$PATH" \
    "$lant_executable" "$@"
}

next_json="$(lant_at "$profile_root" --json next)"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["schema"] == "little-ant/next@1"; assert value["interaction"]["opportunity"]["type"] == "pristine"' <<<"$next_json"

feed_json="$(lant_at "$profile_root" --json feed comprar leite)"
raw_id="$(python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["schema"] == "little-ant/feed@1"; assert value["raw"]["handle"] == "+cl"; print(value["raw"]["id"])' <<<"$feed_json")"

show_json="$(lant_at "$profile_root" --json show +cl)"
python3 -c 'import json,sys; expected=sys.argv[1]; value=json.load(sys.stdin); assert value["schema"] == "little-ant/show-raw@1"; assert value["raw"]["id"] == expected' "$raw_id" <<<"$show_json"

restored_json="$(lant_at "$profile_root" --json next)"
python3 -c 'import json,sys; first=json.loads(sys.argv[1]); restored=json.load(sys.stdin); assert restored["interaction"]["interaction_id"] == first["interaction"]["interaction_id"]' "$feed_json" <<<"$restored_json"

csv_output="$(lant_at "$profile_root" export csv)"
case "$csv_output" in
  id,handle,title,nature,parent_id,domains,sibling_position,status,work_state,phase,effort,impact_class,impact_maturity$'\r') ;;
  *) echo "the built-in CSV exporter was not available through the production environment" >&2; exit 1 ;;
esac

dry_root="$test_root/dry"
lant_at "$dry_root" --json --dry-run feed milk >/dev/null
test -z "$(find "$dry_root/state/lant/profiles/default/dataset/events" -name '*.jsonl' -type f -print 2>/dev/null)"

plain_output="$(TERM=dumb lant_at "$profile_root" next)"
case "$plain_output" in
  *$'\033['*) echo "TERM=dumb output contained ANSI bytes" >&2; exit 1 ;;
esac
case "$plain_output" in
  *"L I T T L E    A N T"*) echo "redirected output contained the startup splash" >&2; exit 1 ;;
esac

before_count="$(find "$state_home/lant/profiles/default/dataset/events" -name '*.jsonl' -type f | wc -l)"
if lant_at "$profile_root" --json --schema 2 feed forbidden >"$test_root/schema.out" 2>"$test_root/schema.err"; then
  echo "unsupported schema unexpectedly succeeded" >&2
  exit 1
fi
python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["code"] == "unsupported"' <"$test_root/schema.err"
after_count="$(find "$state_home/lant/profiles/default/dataset/events" -name '*.jsonl' -type f | wc -l)"
test "$before_count" = "$after_count"
