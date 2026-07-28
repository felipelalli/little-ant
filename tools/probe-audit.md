# Little Ant 1.0 probe mutation audit

This reproducible audit was produced by `bash tools/probe-mutation-check.sh`.
Every row established the exact target as green, changed production behavior
rather than its probe result, reran `tools/v1-progress.py`, and observed that
same target turn red before restoring and rebuilding pristine sources.

- Manifest SHA-256: `7e60fc792165b54c1a26cf991fbc2b048f8d78e5b8d4e4c4ce182dc1679ab999`
- Implementation SHA-256: `18829e81d20ae236ab15d33716ab62f05726dc494a3b8b0a50c0fdfa2e373528`
- Sample size: **30 unique obligations across nine modules**

## Sampled green-to-red results

| Obligation ID | Module | Behavior mutation | Boundary | Outcome |
|---|---|---|---|---|
| `invariant.GloballyOpaqueEntityIds` | `root` | Make kernel entity allocation ignore the ordinal so two real creations collide. | domain | green → red |
| `rule-success.PartyCreated` | `domain` | Change the label retained by real Party creation before rename history is recorded. | domain | green → red |
| `rule-entity-creation.PartyCreated.1` | `domain` | Change the label retained by real Party creation before rename history is recorded. | domain | green → red |
| `rule-failure.InlineRawCaptured.1` | `material` | Start a real inline Raw as reviewed instead of pending. | domain | green → red |
| `rule-failure.InlineRawCaptured.2` | `material` | Start a real inline Raw as reviewed instead of pending. | domain | green → red |
| `rule-entity-creation.InlineRawCaptured.1` | `material` | Start a real inline Raw as reviewed instead of pending. | domain | green → red |
| `rule-failure.FirstRootBrickCreated.1` | `judgment` | Pass an empty title through the real first-root priority creation transition. | domain | green → red |
| `rule-failure.FirstRootBrickCreated.2` | `judgment` | Pass an empty title through the real first-root priority creation transition. | domain | green → red |
| `rule-entity-creation.FirstRootBrickCreated.1` | `judgment` | Pass an empty title through the real first-root priority creation transition. | domain | green → red |
| `rule-failure.IdleBrickFocused.1` | `execution` | Leave a real newly focused Brick idle instead of promoting it to WIP. | domain | green → red |
| `rule-failure.IdleBrickFocused.2` | `execution` | Leave a real newly focused Brick idle instead of promoting it to WIP. | domain | green → red |
| `rule-failure.IdleBrickFocused.3` | `execution` | Leave a real newly focused Brick idle instead of promoting it to WIP. | domain | green → red |
| `rule-success.DeferredPlacementCreatesPriorityProbe` | `selection` | Suppress proposal derivation from a genuinely deferred priority insertion. | domain | green → red |
| `rule-failure.DeferredPlacementCreatesPriorityProbe.1` | `selection` | Suppress proposal derivation from a genuinely deferred priority insertion. | domain | green → red |
| `rule-entity-creation.DeferredPlacementCreatesPriorityProbe.1` | `selection` | Suppress proposal derivation from a genuinely deferred priority insertion. | domain | green → red |
| `rule-entity-creation.InteractionOpened.1` | `interaction` | Persist a newly opened interaction with stale status. | domain | green → red |
| `rule-failure.PoweredUpAdapterValidated.1` | `interaction` | Reject a structurally valid stdin-only powered-up process response. | outside world | green → red |
| `rule-failure.PoweredUpAdapterRejected.1` | `interaction` | Reject a structurally valid stdin-only powered-up process response. | outside world | green → red |
| `contract-signature.PackRunner.execute` | `integration` | Reduce the real Lua process sandbox source-byte limit below every executable component. | outside world | green → red |
| `rule-failure.SynchronizationCompleted.1` | `integration` | Drop the receipt from the real verified source-synchronization completion transition. | outside world | green → red |
| `rule-failure.SynchronizationCompleted.2` | `integration` | Drop the receipt from the real verified source-synchronization completion transition. | outside world | green → red |
| `rule-failure.TaskJugglerManifestGenerated.1` | `integration` | Pin the real TaskJuggler planning manifest to the wrong dataset revision. | outside world | green → red |
| `rule-entity-creation.TaskJugglerManifestGenerated.1` | `integration` | Pin the real TaskJuggler planning manifest to the wrong dataset revision. | outside world | green → red |
| `rule-failure.LocalWebUiOpened.1` | `integration` | Bind the real local web UI session to a non-loopback host. | outside world | green → red |
| `rule-entity-creation.LocalWebUiOpened.1` | `integration` | Bind the real local web UI session to a non-loopback host. | outside world | green → red |
| `contract-signature.ReadOnlyExporterContract.export` | `integration` | Make the executable TaskJuggler Lua exporter return the wrong media type. | outside world | green → red |
| `contract-signature.UIAdapterContract.render` | `integration` | Make the executable loopback UI Lua adapter mark a rendered envelope mutable. | outside world | green → red |
| `rule-failure.CurrentStateProjected.1` | `migration-v0-v1` | Project a real legacy seed as terminal instead of active. | outside world | green → red |
| `rule-failure.CurrentStateProjected.2` | `migration-v0-v1` | Project a real legacy seed as terminal instead of active. | outside world | green → red |
| `rule-failure.CurrentStateProjected.3` | `migration-v0-v1` | Project a real legacy seed as terminal instead of active. | outside world | green → red |

## Stayed-green / fake results

None.

All sampled targets flipped red. No sampled fake required a behavior fix or
an owner decision.
