#!/usr/bin/env bash
set -euo pipefail

test_root="$(mktemp -d /tmp/lant-s01-cli.XXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

lant_executable="$(cabal list-bin exe:lant)"
state_home="$test_root/state"

next_json="$(XDG_STATE_HOME="$state_home" "$lant_executable" --json next)"
python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["schema"] == "little-ant/next@1"; assert value["interaction"]["opportunity"]["type"] == "pristine"' <<<"$next_json"

feed_json="$(XDG_STATE_HOME="$state_home" "$lant_executable" --json feed comprar leite)"
raw_id="$(python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["schema"] == "little-ant/feed@1"; assert value["raw"]["handle"] == "+cl"; print(value["raw"]["id"])' <<<"$feed_json")"

show_json="$(XDG_STATE_HOME="$state_home" "$lant_executable" --json show +cl)"
python3 -c 'import json,sys; expected=sys.argv[1]; value=json.load(sys.stdin); assert value["schema"] == "little-ant/show-raw@1"; assert value["raw"]["id"] == expected' "$raw_id" <<<"$show_json"

restored_json="$(XDG_STATE_HOME="$state_home" "$lant_executable" --json next)"
python3 -c 'import json,sys; first=json.loads(sys.argv[1]); restored=json.load(sys.stdin); assert restored["interaction"]["interaction_id"] == first["interaction"]["interaction_id"]' "$feed_json" <<<"$restored_json"

dry_home="$test_root/dry"
XDG_STATE_HOME="$dry_home" "$lant_executable" --json --dry-run feed milk >/dev/null
test ! -e "$dry_home/lant/profiles/default/dataset"

plain_output="$(TERM=dumb XDG_STATE_HOME="$state_home" "$lant_executable" next)"
case "$plain_output" in
  *$'\033['*) echo "TERM=dumb output contained ANSI bytes" >&2; exit 1 ;;
esac
case "$plain_output" in
  *"L I T T L E    A N T"*) echo "redirected output contained the startup splash" >&2; exit 1 ;;
esac

before_count="$(find "$state_home/lant/profiles/default/dataset/events" -name '*.jsonl' -type f | wc -l)"
if XDG_STATE_HOME="$state_home" "$lant_executable" --json --schema 2 feed forbidden >"$test_root/schema.out" 2>"$test_root/schema.err"; then
  echo "unsupported schema unexpectedly succeeded" >&2
  exit 1
fi
python3 -c 'import json,sys; value=json.load(sys.stdin); assert value["code"] == "unsupported"' <"$test_root/schema.err"
after_count="$(find "$state_home/lant/profiles/default/dataset/events" -name '*.jsonl' -type f | wc -l)"
test "$before_count" = "$after_count"
