#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

manifest_file="$(mktemp "${TMPDIR:-/tmp}/little-ant-probe-mutations.XXXXXX")"
trap 'rm -f -- "$manifest_file"' EXIT HUP INT TERM

# This is the auditable sample manifest. Each row names the exact generated
# obligation, the production-behavior mutation, whether it crosses an outside-
# world boundary, and the behavior an auditor should expect to become visible.
cat >"$manifest_file" <<'MANIFEST'
module	obligation	mutation	boundary	behavior
root	invariant.GloballyOpaqueEntityIds	kernel-opaque-identity	no	Make kernel entity allocation ignore the ordinal so two real creations collide.
domain	rule-success.PartyCreated	domain-party-label	no	Change the label retained by real Party creation before rename history is recorded.
domain	rule-entity-creation.PartyCreated.1	domain-party-label	no	Change the label retained by real Party creation before rename history is recorded.
material	rule-failure.InlineRawCaptured.1	material-inline-review-state	no	Start a real inline Raw as reviewed instead of pending.
material	rule-failure.InlineRawCaptured.2	material-inline-review-state	no	Start a real inline Raw as reviewed instead of pending.
material	rule-entity-creation.InlineRawCaptured.1	material-inline-review-state	no	Start a real inline Raw as reviewed instead of pending.
judgment	rule-failure.FirstRootBrickCreated.1	priority-first-root-title	no	Pass an empty title through the real first-root priority creation transition.
judgment	rule-failure.FirstRootBrickCreated.2	priority-first-root-title	no	Pass an empty title through the real first-root priority creation transition.
judgment	rule-entity-creation.FirstRootBrickCreated.1	priority-first-root-title	no	Pass an empty title through the real first-root priority creation transition.
execution	rule-failure.IdleBrickFocused.1	domain-focused-work-state	no	Leave a real newly focused Brick idle instead of promoting it to WIP.
execution	rule-failure.IdleBrickFocused.2	domain-focused-work-state	no	Leave a real newly focused Brick idle instead of promoting it to WIP.
execution	rule-failure.IdleBrickFocused.3	domain-focused-work-state	no	Leave a real newly focused Brick idle instead of promoting it to WIP.
selection	rule-success.DeferredPlacementCreatesPriorityProbe	selection-deferred-candidate	no	Suppress proposal derivation from a genuinely deferred priority insertion.
selection	rule-failure.DeferredPlacementCreatesPriorityProbe.1	selection-deferred-candidate	no	Suppress proposal derivation from a genuinely deferred priority insertion.
selection	rule-entity-creation.DeferredPlacementCreatesPriorityProbe.1	selection-deferred-candidate	no	Suppress proposal derivation from a genuinely deferred priority insertion.
interaction	rule-entity-creation.InteractionOpened.1	interaction-open-status	no	Persist a newly opened interaction with stale status.
interaction	rule-failure.PoweredUpAdapterValidated.1	powered-up-validation	yes	Reject a structurally valid stdin-only powered-up process response.
interaction	rule-failure.PoweredUpAdapterRejected.1	powered-up-validation	yes	Reject a structurally valid stdin-only powered-up process response.
integration	contract-signature.PackRunner.execute	process-sandbox-source-limit	yes	Reduce the real Lua process sandbox source-byte limit below every executable component.
integration	rule-failure.SynchronizationCompleted.1	source-sync-receipt	yes	Drop the receipt from the real verified source-synchronization completion transition.
integration	rule-failure.SynchronizationCompleted.2	source-sync-receipt	yes	Drop the receipt from the real verified source-synchronization completion transition.
integration	rule-failure.TaskJugglerManifestGenerated.1	taskjuggler-manifest-revision	yes	Pin the real TaskJuggler planning manifest to the wrong dataset revision.
integration	rule-entity-creation.TaskJugglerManifestGenerated.1	taskjuggler-manifest-revision	yes	Pin the real TaskJuggler planning manifest to the wrong dataset revision.
integration	rule-failure.LocalWebUiOpened.1	web-ui-bind-host	yes	Bind the real local web UI session to a non-loopback host.
integration	rule-entity-creation.LocalWebUiOpened.1	web-ui-bind-host	yes	Bind the real local web UI session to a non-loopback host.
integration	contract-signature.ReadOnlyExporterContract.export	taskjuggler-runtime-media	yes	Make the executable TaskJuggler Lua exporter return the wrong media type.
integration	contract-signature.UIAdapterContract.render	web-ui-runtime-read-only	yes	Make the executable loopback UI Lua adapter mark a rendered envelope mutable.
migration-v0-v1	rule-failure.CurrentStateProjected.1	migration-seed-status	yes	Project a real legacy seed as terminal instead of active.
migration-v0-v1	rule-failure.CurrentStateProjected.2	migration-seed-status	yes	Project a real legacy seed as terminal instead of active.
migration-v0-v1	rule-failure.CurrentStateProjected.3	migration-seed-status	yes	Project a real legacy seed as terminal instead of active.
MANIFEST

case "${1:-}" in
  --print-manifest)
    cat "$manifest_file"
    ;;
  --validate-only)
    python3 tools/probe_mutation.py validate-manifest --manifest "$manifest_file"
    ;;
  --validate-audit)
    if [[ $# -ne 2 ]]; then
      echo "usage: $0 --validate-audit AUDIT_FILE" >&2
      exit 2
    fi
    python3 tools/probe_mutation.py validate-audit \
      --manifest "$manifest_file" --audit "$2"
    ;;
  --write-audit)
    if [[ $# -ne 2 ]]; then
      echo "usage: $0 --write-audit AUDIT_FILE" >&2
      exit 2
    fi
    python3 tools/probe_mutation.py run \
      --manifest "$manifest_file" --write-audit "$2"
    ;;
  --verify-audit)
    if [[ $# -ne 2 ]]; then
      echo "usage: $0 --verify-audit AUDIT_FILE" >&2
      exit 2
    fi
    python3 tools/probe_mutation.py run \
      --manifest "$manifest_file" --verify-audit "$2"
    ;;
  "")
    python3 tools/probe_mutation.py run --manifest "$manifest_file"
    ;;
  *)
    echo "usage: $0 [--validate-only|--print-manifest|--validate-audit FILE|--write-audit FILE|--verify-audit FILE]" >&2
    exit 2
    ;;
esac
