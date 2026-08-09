# ADR 0007: Bind Pack authority to one operation and artifact

## Status

Accepted for S09.

## Context

A structurally valid Pack proves only that one bounded canonical archive obeys
the format. A valid Ed25519 signature proves who authenticated its exact
manifest. Neither fact alone grants installation or execution authority.

Official-catalog expiry creates a deliberate asymmetry: it blocks a new
official installation or update, while an already accepted, exactly pinned,
non-revoked archive may continue running offline. A single generic trusted
Pack capability could accidentally carry execution-only authority into an
installer.

## Decision

Pack authority crosses four explicit boundaries:

1. `StructurallyValidPack` contains canonical, bounded, digest-checked bytes;
2. `AuthenticatedPack` verifies the exact manifest signature, canonical
   Ed25519 public key, and full key fingerprint;
3. `PackTrustAssessment` renders exactly one canonical trust class and keeps
   official-catalog freshness separate from that class;
4. distinct opaque `InstallAuthorizedPack` and `ExecutionAuthorizedPack`
   capabilities bind one profile scope, signer, manifest digest, archive
   digest, version, and enabled component set.

Revocation is checked last and dominates built-in, official, and community
trust. New official installation requires a current accepted catalog. Existing
official execution uses the acceptance provenance stored in its exact pin and
therefore survives catalog expiry, but never a known key or archive
revocation. Community execution continues only while that exact publisher key
remains trusted in the selected profile.

## Consequences

- the installer cannot accept an execution authorization, and the executable
  registry cannot accept an installation authorization;
- trust in one profile, signer, version, or archive cannot authorize another;
- catalog staleness is visible without falsely relabeling an accepted official
  release as community or untrusted;
- catalog parsing, persistent pins, and the component registry can be added
  behind these capabilities without weakening the boundary.
