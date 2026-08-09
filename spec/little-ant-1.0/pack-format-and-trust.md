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

### Closed `little-ant/pack@1` object shape

The top-level object contains exactly these required keys:

```text
schema                  literal "little-ant/pack@1"
name                    reverse-DNS Pack name
version                 complete SemVer 2.0.0 string
display_name            nonempty human label
publisher               reverse-DNS publisher ID
little_ant_major        positive integer
components              nonempty array of component objects
files                   array of payload-file objects
```

It may additionally contain `links`, an object whose only keys are `homepage`,
`source`, and `changelog` and whose values are absolute `https` URLs. No link
grants network authority. Names and IDs use lowercase ASCII. A reverse-DNS ID
has at least two dot-separated labels; each label begins and ends with an ASCII
letter or digit and may contain internal hyphens.

Every component object has exactly these common keys:

```text
id                      Pack-local [a-z][a-z0-9._-]{0,63} identifier
kind                    one exact DAT-019 component kind
contract_major          positive integer
root                    Pack-relative payload directory owned by the component
configuration_schema    file path relative to root
```

Component IDs and roots are unique. Roots cannot overlap: no component root is
another component root or its ancestor. Every declared payload file belongs to
exactly one component root. `configuration_schema` names a declared file under
that root; a component with no settings uses a signed schema that accepts only
an empty object rather than omitting this field.

A declarative `BrickNature`, `BrickTemplate`, or `ImportProfilePreset` adds
exactly `declarative_body`, a declared JSON file relative to its root. It has no
`entry_point` or `permissions` key. An executable `SourceAdapter`,
`ReadOnlyExporter`, or `UIAdapter` instead adds exactly `entry_point` and
`permissions`. The entry point is a declared Lua file relative to its root.
Permissions are per component; there is no Pack-wide permission union.

The executable permissions object contains all five arrays below, including
the empty ones:

```text
credential_slots        declared credential-slot objects
http                    host-brokered HTTP-rule objects
effect_purposes         closed DAT-068 purpose strings
projections             named versioned input projections
host_capabilities       closed host-capability strings
```

A credential-slot object has only `id` and `scheme`. Its ID follows the
component-ID grammar. The schemes are
`oauth2_authorization_code_pkce`, `oauth2_device_authorization`,
`bearer_token`, and `api_key`; a component needing no authentication declares
no slot. An HTTP rule has only `methods`, `host`, `path_prefix`, and the
optional `credential_slot`. Methods are a nonempty set drawn from `GET`,
`POST`, `PUT`, `PATCH`, and `DELETE`; `host` is one exact lowercase ASCII DNS
name without wildcard or port; `path_prefix` is an absolute URL path without
query, fragment, empty, `.` or `..` component; and a credential reference must
resolve inside the same component.

The effect-purpose strings are exactly `delegation_delivery`,
`delegation_take_back_notice`, `source_cleanup_item`,
`source_cleanup_container`, `calendar_create`, `calendar_update`, and
`calendar_cancel`. The 1.0 host capabilities are `input_bytes`,
`loopback_http`, and `static_assets`. A projection is a nonempty named schema
with an explicit positive major version. Duplicate permission entries are
invalid.

Declarative components cannot request authority. `ReadOnlyExporter` requires
at least one projection and requires all other permission arrays to be empty.
A `SourceAdapter` cannot request UI host capabilities. A `UIAdapter` cannot
request an effect purpose. These kind checks supplement the invocation
contract: the host exposes only both declared and kind-valid capabilities.

A payload-file object contains exactly `path`, `length`, `media_type`, and
`sha256`. The path is relative to `payload/` and follows the archive path
rules, length is a nonnegative integer, media type is nonempty ASCII, and the
digest is 64 lowercase hexadecimal characters. `files` is sorted by unsigned
UTF-8 path bytes and corresponds one-for-one with the archive payload entries.
Signed Pack control documents use only integers in the interoperable JSON
integer range; arbitrary declarative and configuration-schema JSON lives in
payload files and remains covered byte-for-byte by this list.

`signature.json` is JCS JSON with schema `little-ant/pack-signature@1`,
algorithm literal `Ed25519`, the publisher public key, its full SHA-256 key
fingerprint, and a base64url signature over the exact `pack.json` bytes.
Ed25519 follows [RFC 8032](https://www.rfc-editor.org/rfc/rfc8032). The host
then verifies every declared payload size and digest. Reusing the same
publisher/name/version with different archive or manifest digest is an
equivocation error, not an update.

The signature object contains exactly `schema`, `algorithm`, `public_key`,
`key_fingerprint`, and `signature`. Public key and signature are unpadded
base64url encodings of respectively 32 and 64 bytes. The fingerprint is the
64-character lowercase SHA-256 of the decoded public key. No display label in
either control document participates in signer authorization.

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

The catalog object contains exactly `schema`, `sequence`, `expires_at`,
`delegations`, `releases`, and `revocations`. A delegation contains exactly
`publisher`, `public_key`, `key_fingerprint`, and nonempty `name_prefixes`.
There is at most one delegation for a publisher. A release contains exactly
`publisher`, `name`, `version`, `manifest_sha256`, and `archive_sha256`; its
publisher must exist and its name must match at least one delegated prefix.
A revocation contains exactly `target`, `sha256`, `reason`, and
`effective_at`, where `target` is `publisher_key` or `archive`. Duplicate
release identities, publisher delegations, prefixes, or revocation targets
are invalid rather than resolved by array order.

The detached catalog signature contains exactly `schema`, `algorithm`,
`root_fingerprint`, and `signature`; it never carries a self-authorizing root
key. A root-transition document contains exactly `schema`, `generation`, both
the previous and replacement root public keys, and their fingerprints. Its
detached `little-ant/catalog-root-proof@1` contains exactly `schema`,
`algorithm`, `previous_signature`, and `next_signature`. Generations are
contiguous and both signatures cover the same exact transition bytes. Keeping
both keys in that cross-signed document lets a later binary whose compiled
anchor is either side verify the same history without silently trusting a key
read from local state.

Accepted catalogs and root transitions are appended to one ordered,
cryptographically replayable history at
`$XDG_STATE_HOME/lant/profiles/<name>/official-pack-catalog.json`. The closed
`little-ant/pack-catalog-state@1` document contains only `schema` and
`history`; each history row contains exact base64url `document` and `proof`
bytes plus kind `catalog` or `root_transition`. It is a private regular file
replaced atomically while holding the profile catalog lock. Every read replays
the signatures, root chain, and increasing catalog sequences from a compiled
root anchor. Refresh accepts only an unexpired, strictly newer catalog.
Previously accepted revocations are unioned across the verified history and
become effective at their declared instants, so omission from a later catalog
cannot resurrect a key or archive.

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

Installation authority and execution authority are distinct,
non-interchangeable host capabilities. Each names the selected profile, signer
fingerprint, Pack identity, exact manifest/archive digests, and enabled
components. Catalog expiry can therefore deny a new official install/update
without granting that installer the execution-only authority retained by an
already accepted pin. No generic `trusted Pack` token crosses these
operations, and every capability is rechecked against locally known key and
archive revocations before use.

The content-addressed store path is
`$XDG_DATA_HOME/lant/packs/sha256/<archive-sha256>.lantpack`. Store files are
private regular files and are never replaced in place. Every load checks the
filename digest, reconstructs the canonical archive, authenticates its exact
manifest, and re-evaluates the selected profile pin before a component enters
the registry. A symlink, non-private file, digest mismatch, malformed archive,
invalid signature, revoked signer/archive, or mismatched pin fails closed.

Within `little-ant/integrations@1`, `installed_components` is an object keyed
by exact Pack name. Each value contains exactly `artifact`,
`signer_fingerprint`, `trust`, and `enabled_components`. `artifact` contains
exactly `publisher`, `name`, `version`, `manifest_sha256`, and
`archive_sha256`; `trust` contains `class` and, only for `verified_official`,
`catalog_sequence`. `trusted_publishers` is an array of objects containing
exactly `publisher`, `public_key`, and `fingerprint`. Pins and approved keys
are validated while reading and before an atomic configuration write.

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
