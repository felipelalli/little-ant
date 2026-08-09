# ADR 0024 — Publish the official Pack root without private-key custody in Git

Status: accepted for S09

## Context

The Pack trust kernel already verified signed catalog history and historical
official pins, but production deliberately declared official authority
unavailable. Publishing a fixture key would let anyone mint an official
release. Generating a one-off key and discarding it would make refresh and root
rotation impossible. Treating a profile pin as authority would bypass the
catalog entirely.

The public command also needs a stable boundary between network observation
and installation consent. Refresh must never install code, while installation
must not turn a mutable URL into the bytes accepted by an old preview.

## Decision

V1 compiles generation-zero Ed25519 root fingerprint
`1d2688f6b05bf1af1134a2774dc075090fe2ce16ebe9805b721a0cbac85fc410`.
The repository publishes only its public document, the canonical signed
catalog, and archives named by SHA-256. The private 32-byte seed lives outside
the checkout in a private maintainer-controlled file and must be backed up
independently. `tools/official-catalog.hs` reads that file only when explicitly
invoked, rejects group/other access and any path inside the checkout, verifies
the existing publication, requires a strictly increasing sequence and future
expiry, and carries remembered revocations forward. It never generates or
stores a private key.

The production host fetches only fixed HTTPS locations below
`https://raw.githubusercontent.com/felipelalli/little-ant/main/packs/official/`
with redirects disabled and bounded response sizes. `lant packs refresh`
authenticates the exact catalog/signature against the active root chain before
writing profile history. An identical accepted sequence is an idempotent
`already current` result; an older sequence, same-sequence different document,
invalid signature, noncanonical document, or expired candidate changes
nothing. Dry-run performs the same fetch and verification without writing
catalog history.

`lant packs install <name[@version]>` resolves only accepted current catalog
grants. An unversioned name is accepted only when it identifies one release.
The host downloads the digest-named archive, verifies its digest, canonical
structure, signature, signer delegation, exact release identity, and component
authority, then stores the bytes in a private profile-local content-addressed
download cache. That cache is only stable preview custody. The ordinary
no-default Pack installation Interaction reopens it; acceptance alone publishes
the archive to the global store and compare-and-swaps the official profile pin.

The dumb `/packs` manager exposes explicit refresh and accepts either an
official name or local archive path. After refresh, trust, or installation, a
long-running REPL rebuilds its production registry before invoking another
component so new revocations or authority cannot remain stale in memory.

## Consequences and verification

- the official connector remains separately installed and removable rather
  than becoming a privileged built-in;
- catalog network access never grants installation consent;
- consent is bound to immutable cached bytes rather than a URL;
- losing the external private root prevents same-root publications and must be
  treated as a release-security incident, not repaired with a repository key;
- tests cover initial/idempotent refresh, tamper rejection, dry-run isolation,
  exact official install, absence of community trust, private cache custody,
  historical official pinning, and startup replay through the compiled root;
  and
- the maintenance verifier reconstructs the public release and authenticates
  the catalog independently of production profile state.
