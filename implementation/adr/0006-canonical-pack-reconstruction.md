# ADR 0006: Canonical Pack reconstruction

## Status

Accepted for the S09 structural Pack milestone.

## Canonical constraints served

- DAT-086 and the Pack format require one reproducible ZIP32/store archive,
  strict entry order and metadata, bounded paths and sizes, JCS control
  documents, and complete validation before extraction or Lua startup.
- DAT-019..021 require a closed component catalog and keep executable Pack
  code outside replay and outside the trusted process.
- The closed `little-ant/pack@1` schema grants authority per executable
  component, never as a Pack-wide union.

## Considered physical designs

A general ZIP extractor would decode the payload but could discard local-header
details, tolerate alternative encodings, or expose files before the host had
proved canonicality. Validating selected decoded fields would leave unexamined
ZIP flags and central-directory representations. A native binary parser for
every possible ZIP feature would add complexity even though the accepted
format intentionally has only one representation.

## Decision

The trusted host parses only enough bounded ZIP32 structure to obtain the local
entry names and stored bytes. It then rebuilds the complete archive with the
one canonical writer and requires byte-for-byte equality with the candidate.
This single comparison covers local and central records, flags, versions,
timestamps, modes, offsets, CRC32, ordering, comments, extra fields, data
descriptors, ZIP64, and trailing bytes. Nothing is extracted to the filesystem.

The host separately JCS-decodes and re-encodes both control documents, strictly
decodes their closed schemas, validates component-local permissions and file
ownership, and checks every payload length and SHA-256. The structural result
is deliberately not a trusted or executable Pack; later authority code must
authenticate its Ed25519 signature and classify its signer before the registry
can receive it.

Pack control schemas use only interoperable JSON integers. Configuration
schemas and declarative bodies remain signed payload files, so the control
canonicalizer does not need to accept application-specific fractional values.

## Verification

`little-ant-s09-pack-format-test` proves reproducible round-trip bytes, exact
JCS ordering, fail-closed ZIP mutation and trailing-data handling, closed
control keys, component-local permission constraints, unambiguous roots and
ownership, payload size/digest matching, and path traversal and Unicode
normalization rejection.
