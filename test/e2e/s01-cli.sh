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

taskjuggler_output="$test_root/little-ant.tjp"
lant_at "$profile_root" export taskjuggler --output "$taskjuggler_output" >/dev/null
grep -q '^# LANT-MANIFEST-SHA256: ' "$taskjuggler_output"
tj3 --check-syntax --no-reports "$taskjuggler_output" >/dev/null

import_root="$test_root/import-profile"
plain_source="$test_root/notes.txt"
printf '%s\n' 'First note' 'Second note' >"$plain_source"
if lant_at "$import_root" import "$plain_source" >"$test_root/import-missing-mode.out" 2>"$test_root/import-missing-mode.err"; then
  echo "import without an explicit mode unexpectedly succeeded" >&2
  exit 1
fi
grep -q -- '--snapshot' "$test_root/import-missing-mode.err"
if lant_at "$import_root" import "$plain_source" --mode snapshot >"$test_root/import-alias.out" 2>"$test_root/import-alias.err"; then
  echo "removed import --mode grammar unexpectedly succeeded" >&2
  exit 1
fi
grep -q -- '--mode' "$test_root/import-alias.err"
import_json="$(lant_at "$import_root" --json import "$plain_source" --snapshot)"
python3 -c '
import json,sys
value=json.load(sys.stdin)
interaction=value["interaction"]
assert interaction["opportunity"]["type"] == "import_preflight"
assert interaction["opportunity"]["preflight"]["mode"] == "snapshot"
assert [action["id"] for action in interaction["actions"]] == ["import.accept", "import.back", "import.unknown", "palette.open"]
assert not any(action["default"] for action in interaction["actions"])
' <<<"$import_json"
test -z "$(find "$import_root/state/lant/profiles/default/dataset/events" -name '*.jsonl' -type f -print 2>/dev/null)"

actuals_source="$test_root/actuals.tjp"
python3 - "$actuals_source" <<'PY'
import base64, hashlib, json, pathlib, sys

brick = "0198f000-0000-7000-8000-000000000011"
task = "t_" + brick.replace("-", "")
manifest = {
    "calendars": [],
    "cut": [{"brick_id": brick, "dependencies": [], "order": 0, "task_id": task}],
    "effort_profile": {"id": "fixture"},
    "exporter": {"component": "taskjuggler"},
    "planned_at": "2026-08-09T09:00:00Z",
    "projection": {"schema": "little-ant/taskjuggler@1"},
    "resources": [],
    "roots": [],
    "schema": "little-ant/planning-manifest@1",
    "scope": {"kind": "all"},
    "source": {"cursor": "0:fixture", "hash": "a" * 64},
    "warnings": [],
}
canonical = json.dumps(manifest, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()
digest = hashlib.sha256(canonical).hexdigest()
encoded = base64.urlsafe_b64encode(canonical).decode().rstrip("=")
lines = [f"# LANT-MANIFEST-SHA256: {digest}"]
for index, offset in enumerate(range(0, len(encoded), 160), 1):
    lines.append(f"# LANT-MANIFEST-JCS-BASE64URL-{index:04d}: {encoded[offset:offset + 160]}")
lines += [
    "",
    'project p "Actuals" "1.0" 2026-08-01 +1m {',
    '  timezone "UTC"',
    "  now 2026-08-09-09:00",
    '  scenario plan "Plan" {',
    '    scenario actual "Actual"',
    "  }",
    "  trackingscenario actual",
    "}",
    "",
    'resource me "Me"',
    "",
    f'task {task} "Fixture work" {{',
    "  effort 6h",
    "  allocate me",
    "  actual:effortdone 2h",
    "  actual:effortleft 4h",
    "}",
]
pathlib.Path(sys.argv[1]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
tj3 --check-syntax --no-reports "$actuals_source" >/dev/null
actuals_json="$(lant_at "$import_root" --json import "$actuals_source" --snapshot)"
python3 -c '
import json,sys
value=json.load(sys.stdin)
preflight=value["interaction"]["opportunity"]["preflight"]
observation=preflight["observation"]
assert preflight["adapter_id"] == "taskjuggler_actuals"
assert preflight["mode"] == "snapshot"
assert observation["identity"]["actuals_as_of"] == "2026-08-09-09:00Z"
assert observation["identity"]["actual_record_count"] == "1"
assert "Planning manifest:" in "\n".join(value["interaction"]["content"]["body"])
' <<<"$actuals_json"
test -z "$(find "$import_root/state/lant/profiles/default/dataset/events" -name '*.jsonl' -type f -print 2>/dev/null)"

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
