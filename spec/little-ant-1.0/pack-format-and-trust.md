# Pack format and trust

Status: **Little Ant 1.0 normative Pack format**

The 1.0 format favors inspectability and reproducibility over compression or a
general dependency ecosystem.

## Canonical `.lantpack` archive

A `.lantpack` is a ZIP32 archive using only the `store` method. Its entries
are, in order:

```text
pack.json
signature.json
payload/<manifest-sorted path 1>
payload/<manifest-sorted path 2>
...
```

The canonical writer applies all of these rules:

- UTF-8 names with the ZIP UTF-8 flag, sorted by unsigned UTF-8 bytes;
- `pack.json` first, `signature.json` second, then payload order;
- no directory entries, compression, encryption, data descriptors, ZIP64,
  comments, or extra fields;
- DOS date/time `1980-01-01 00:00:00`, creator `Unix`, extraction version
  `2.0`, and regular-file mode `0644` for every entry;
- forward-slash relative paths, no empty component, `.`, `..`, backslash,
  leading slash, NUL, duplicate, or Unicode-normalization collision;
- at most 4,096 entries, 240 UTF-8 bytes per path, 16 MiB per file, and 64 MiB
  total payload in 1.0; and
- exactly one central-directory record per local record and no bytes after the
  end record.

The host validates the archive and all size/path limits before extracting or
starting Lua. Independently packing identical manifest, signature, and payload
bytes therefore produces an identical archive SHA-256 digest.

## Manifest and signature

`pack.json` is UTF-8 JSON in the
[RFC 8785 JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785).
Its schema is `little-ant/pack@1`. It contains:

- reverse-DNS Pack name, SemVer 2.0.0 version, display name, publisher ID, and
  optional informational homepage/source/changelog links;
- supported Little Ant and component-contract major versions;
- every component, its one DAT-019 kind, entry point or declarative body,
  configuration schema, and permissions;
- exact credential slots, HTTP method/host/path constraints, effect purposes,
  projections, and host capabilities per executable component; and
- a path-sorted list of every payload file's path, byte length, media type, and
  lowercase SHA-256 digest.

Unknown manifest keys or permissions are errors. Informational text and links
are untrusted display data and never grant authority.

`signature.json` is JCS JSON with schema `little-ant/pack-signature@1`,
algorithm literal `Ed25519`, the publisher public key, its full SHA-256 key
fingerprint, and a base64url signature over the exact `pack.json` bytes.
Ed25519 follows [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032). The host
then verifies every declared payload size and digest. Reusing the same
publisher/name/version with different archive or manifest digest is an
equivocation error, not an update.

## Trust classes

The host renders exactly one trust class:

```text
built in | verified official | trusted publisher | untrusted | revoked
```

- The offline standard Pack is built in and still carries a verified manifest
  and archive digest.
- The binary embeds the official catalog root public key. The signed catalog
  has a monotonically increasing sequence, expiry, delegated Pack publisher
  keys, exact release digests, and revoked keys/digests. Root rotation requires
  a transition signed by both the currently trusted and replacement root; a
  later binary may also establish a new compiled root.
- `lant packs refresh` (or refresh inside `/packs`) is the only
  catalog-network action. It is explicit, stores
  only a newer valid catalog, and never installs or updates a Pack. Expired
  catalog metadata blocks a new official install/update but does not stop an
  already pinned archive unless a locally known revocation covers it.
- A community key becomes trusted only through `lant packs trust <key-file>`
  or the trust action inside `/packs`, after displaying its full fingerprint
  and publisher label. Trust is local to the
  selected profile. Unsigned Packs are rejected. Community trust has no
  central revocation claim; `lant packs untrust` disables that publisher's
  components until explicitly trusted again.
- A known revoked key or digest cannot execute, install, update, or receive an
  override. Canonical data and Pack-free replay remain available. Recovery is
  to use a non-revoked signed release or replace the integration.

Official catalog metadata uses JCS schema `little-ant/pack-catalog@1` with
nonnegative integer sequence, RFC 3339 expiry instant, delegated publisher
keys and name prefixes, releases keyed by Pack/version with manifest and
archive SHA-256, and revocations with reason and effective instant. A detached
`little-ant/catalog-signature@1` Ed25519 signature covers its exact bytes.
Sequence must strictly increase. A root transition uses
`little-ant/catalog-root@1` and is accepted only when the exact same transition
bytes carry valid signatures from both roots.

## Dependencies, activation, and updates

Packs have no dependencies on other Packs and no install scripts. A component
may load only payload files inside its own declared component root plus the
versioned pure Lua modules supplied by its host contract. All third-party Lua
source must be vendored and covered by the manifest. Pack code cannot fetch or
generate executable code.

Archives live side by side in a content-addressed local store. A profile pins
Pack name, version, manifest digest, archive digest, and enabled components in
`integrations.yaml`. Installation verifies and stores an archive, then changes
only that pin after preview. It creates no canonical work event.

There is no background or automatic update. `lant packs updates` is read-only.
`lant packs update` downloads and verifies one candidate, then shows signer,
version/digests, component additions/removals, permission and host-allowlist
changes, configuration-schema changes, and affected bindings. Acceptance may
activate the new pin and explicitly rebind the listed integrations; otherwise
old bindings retain their old installed version. Existing Bricks retain their
resolved Nature snapshot and existing accepted results retain their recorded
component provenance.

`lant packs remove` deactivates a profile pin only after affected SourceBindings,
DeliveryBindings, pending effects, and configured UIAdapters are re-bound,
paused, rejected, or explicitly left unavailable. It deletes no canonical
data. `lant packs gc` may delete only archives with no active pin, binding,
pending effect, or retained reproducibility manifest; it previews the exact
bytes and never runs automatically.

[Semantic Versioning 2.0.0](https://semver.org/) labels releases, but trust and
identity always use the exact signed digests rather than a version range.
