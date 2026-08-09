# ADR 0023 — Keep Pack navigation outside canonical consent

Status: accepted for the S09 REPL Pack-manager milestone.

## Context

The application core already exposes sparse read-only Pack list/detail results
and persisted `PackInstallOpportunity` and `PackTrustOpportunity` envelopes.
The REPL still needs a convenient `/packs` entry point, row navigation, and a
way to collect local archive or publisher-key paths. Treating that manager as
another core Opportunity would make harmless presentation navigation part of
the consent protocol and invite surfaces to implement two competing Pack
grammars.

## Decision

The `/packs` manager is surface-local, non-consequential navigation over exact
core command results. It may select a Pack for `PacksShowCommand` or collect a
path for `PacksInstallCommand` or `PacksTrustCommand`. It may not classify,
prefill, reorder, accept, or bypass any action in the resulting canonical
InteractionEnvelope.

Enter means only read-only inspection of the selected row. Trust and install
remain separate, persisted, no-default consent screens owned by the
application core. The REPL uses their canonical shortcuts and response
validation unchanged.

Because accepted trust or installation changes which components may execute,
the long-running REPL reconstructs its production environment immediately
after the corresponding result envelope. A failed reconstruction leaves the
new canonical state intact, reports the failure, and grants no stale component
additional authority.

## Consequences

- REPL, Skill, and future web clients can choose navigation appropriate to
  their medium while invoking the same command and consent contracts;
- harmless list, filter, selection, and file-path editing do not create domain
  events or presentation checkpoints;
- keyboard convenience cannot become implicit trust or installation; and
- a Pack installed during one REPL session becomes available to later commands
  in that session without weakening registry validation.
