# ADR 0025 — Connect providers without persisting device sessions

Status: accepted for S09

## Context

The trusted host already implemented OAuth Device Authorization, typed local
ProviderAccounts and CredentialBindings, encrypted vault custody, and
provider-backed SourceAdapters. The remaining public orchestration had two
competing pressures:

- connection needs a durable, no-default preview of exact signed authority;
- the opaque OAuth device code must not enter the Interaction checkpoint that
  survives process boundaries.

Adding `/connect` as another root command would also widen the closed daily
grammar even though account connection is local typed configuration.

## Decision

Provider connection is a `config connect` subcommand and a contextual recovery
from an unconfigured online source in `/import`. It is not an alias and does
not adopt source data.

The command stores only a public connection draft in the ordinary sealed
InteractionEnvelope: source/component, account key and label, public client
ID, exact Pack identity, signed scopes, opaque future vault-entry UUID, and the
observed integrations revision. Acceptance reopens the selected profile,
rebuilds its execution-authorized Pack registry, and recomputes the complete
draft. Drift returns a fresh unapproved preview.

After consent, one host invocation checks that the profile vault is already
unlocked, starts Device Authorization, presents only its verification URI,
user code, and expiry, and polls to a terminal outcome. The session and device
code remain in memory. Success writes the closed token set through the vault
agent before compare-and-swap inserts the ProviderAccount and
CredentialBinding. The reverse order is forbidden because it could expose a
configured binding with no credential. A lost profile race can leave only an
unreferenced encrypted vault entry, which is safe to collect during a later
maintenance pass.

Production source discovery requires an installed component only when at
least one configured account references it. A clean offline profile therefore
does not become unhealthy merely because an optional official connector is
absent.

## Consequences and verification

- neither OAuth device codes nor tokens are serializable connection-draft
  fields;
- dry-run and preview execute no OAuth request and mutate no local state;
- locked credentials fail before authorization starts and retain the preview;
- Pack, client ID, scope, account, binding, or profile drift requires renewed
  consent;
- a successful connection makes the provider source visible through the same
  ImportPort used by file Sources, but performs no import by itself; and
- focused production-path coverage installs the exact official connector,
  executes a fake Device Flow against a real encrypted vault agent, verifies
  the typed configuration, restarts the host, and observes Microsoft To Do in
  the import catalog without leaking the fixture code or token.

## Rejected alternatives

- A root `/connect` command duplicates the configuration hub and expands the
  canonical grammar.
- Persisting the device session in an InteractionEnvelope would turn an OAuth
  credential into presentation state.
- Writing the binding before the vault entry creates a locally advertised but
  unusable provider account after interruption.
- Automatically importing after authorization transfers connection consent to
  a distinct Raw-adoption decision.
