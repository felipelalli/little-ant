# ADR 0026 — Accept signed source material generically

Status: accepted for S09

## Context

The SourceAdapter runner and trusted host already validate one closed,
versioned observation/materialization contract. File adapters and provider
adapters both return the same host-owned input custody, signed Pack identity,
stable source-object identities, material summaries, and consent-gated full
material. Despite that shared boundary, canonical acceptance still contained
an adapter-name whitelist for the three initial offline adapters. Microsoft To
Do could therefore preflight and materialize through its real signed Pack but
could not preserve the verified result as Raw truth.

Provider selection also has two lifetimes. A single configured account may use
the convenient public selector `adapter`, while its durable source/account
scope must not change when another account is configured later.

## Decision

Canonical acceptance consumes the generic validated SourceAdapter contract,
not an adapter-name or material-shape whitelist. It requires a nonempty exact
source reference and at least one previewed object, verifies that reacquired
input custody and every material summary reproduce the accepted preflight, and
then records the existing ImportProfile, Raw, SourceBinding, and immutable
ImportInvocation facts atomically. Text, URI, blob, and structured material
remain distinct canonical Raw content variants.

Adapter-specific semantic evidence remains an explicit additional validator.
TaskJuggler actuals still receive independent manifest, cutoff, membership, and
monotonicity checks; ordinary adapters neither manufacture nor bypass that
evidence path.

Every provider source now has both a public selection reference and a canonical
`adapter@account` reference. Preflight normalizes to the canonical reference,
which is retained by the ImportProfile and used for materialization and exact
retry. This is identity normalization, not a compatibility alias: the public
reference selects a currently unambiguous account, while durable custody always
names that account explicitly.

## Consequences and verification

- a new signed SourceAdapter can preserve verified Raw material without a core
  release solely to extend an adapter whitelist;
- Pack authority alone is insufficient: observation, input custody,
  materialization equality, stable identities, and replay invariants still
  fail closed before mutation;
- adding a second provider account cannot reinterpret an earlier
  ImportProfile;
- the real Microsoft To Do Pack, broker, credential boundary, and fake Graph
  transport now execute preflight, materialization, canonical acceptance, and
  exact event-free retry through the application; and
- cleanup may now be planned from durable provider Raw, SourceBinding,
  ImportProfile, and ImportInvocation custody rather than transient provider
  responses.
