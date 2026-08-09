# Official Pack publication

This directory is the public, immutable-by-sequence publication surface for
Little Ant's official Pack catalog.

- `catalog-root.json` documents the public root compiled into the V1 binary.
- `catalog.json` is the canonical JCS catalog document.
- `catalog-signature.json` authenticates the exact catalog bytes.
- `releases/<archive-sha256>.lantpack` names every archive by its verified
  content digest.

The Ed25519 private root never belongs in this repository. A release
maintainer must keep a backed-up 32-byte seed in a private regular file outside
the checkout with no group or other permissions. The maintenance tool refuses
an in-repository key, a permissive key file, a non-increasing sequence, an
expired publication, or a key that differs from the already published root.

To publish a strictly newer catalog after rebuilding and reviewing the
official connector Pack:

```sh
cabal exec runghc -- -XGHC2021 -XDerivingStrategies -XLambdaCase \
  -XOverloadedStrings -isrc tools/official-catalog.hs \
  sign /outside/the/repository/catalog-root.ed25519 2 2029-08-09T00:00:00Z

cabal exec runghc -- -XGHC2021 -XDerivingStrategies -XLambdaCase \
  -XOverloadedStrings -isrc tools/official-catalog.hs verify
```

The signer carries every previously published revocation forward so a new
installation never needs older catalog files to learn known withdrawals.
Review and commit only the public files after `verify` succeeds.
