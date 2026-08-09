# ADR 0022 — Bind Pack consent to file and profile revisions

Status: accepted for the S09 Pack trust/install milestone.

## Context

UX-PACK00 separates community signer trust from Pack installation. Both
questions can survive a CLI process and later resume in the REPL, while the
selected archive, publisher-key file, or profile configuration may change in
between. Persisting file bytes in the presentation checkpoint would duplicate
untrusted material. Reusing a prior yes after silently rebuilding a candidate
would authorize facts the person never saw. Blind YAML writes could also erase
another process's newer profile change.

## Decision

Pending Pack opportunities retain only a canonical absolute path, the exact
raw-byte SHA-256, validated signed identity or publisher key, and the exact
`integrations.yaml` revision. They never retain archive bytes or an executable
authorization capability.

Every acceptance reopens one bounded regular nonsymlink file and repeats
structural validation, authentication, compatibility, trust, and component
authorization. Missing or changed file bytes are a hard conflict and discard
the pending checkpoint. Profile drift instead regenerates the applicable trust
or installation screen with no default and no carried acceptance.

Profile mutation takes an exclusive integrations lock and compares the exact
revision immediately before an atomic write. Pack installation publishes the
authorized archive to the content-addressed store first and then attempts this
compare-and-swap pin. A losing writer therefore leaves at most an unreferenced
artifact for later garbage collection. Only the exact pin in
`integrations.yaml` makes a Pack installed.

The standalone key transport is closed RFC 8785 JSON schema
`little-ant/pack-publisher-key@1`; it reuses the same publisher/public-key/
fingerprint validation as profile trust. Trusting from an archive is a nested
subflow of that installation opportunity, and successful trust always returns
to a still-unapproved install preview.

## Consequences

- `--dry-run` can execute the complete validation path while persisting no
  checkpoint, trust, archive, or pin;
- a yes is bound to exactly the file and profile state shown;
- concurrent profile writers cannot silently clobber one another;
- archive-first publication remains crash-safe without inventing a second
  installed-state marker; and
- community pins remain valid when the same explicitly trusted key later also
  receives official classification, unless its key or archive is revoked.
