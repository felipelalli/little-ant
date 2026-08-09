# ADR 0016 — Broker Pack HTTP through transcript replay

Status: accepted for S09

## Canonical constraints

Packs may describe provider-specific behavior, but Lua must never receive
network authority or provider credentials. The host owns TLS, credential
injection, exact destination enforcement, redirects, timeouts, cancellation,
rate and body limits, retries, JSON framing, and redaction. Replay must remain
offline and must never invoke either a Pack or a provider.

SourceAdapter components nevertheless need a small synchronous request API for
adaptive JSON providers: one response may select the next page or child route.
The isolated runner intentionally creates a fresh process and Lua VM for every
step, so retaining a live interpreter around network calls would weaken the
existing process boundary.

## Considered implementations

1. Give Lua direct network and credential access. This violates the Pack trust
   boundary and makes destination and secret confinement depend on component
   code.
2. Implement each provider in privileged Haskell. This duplicates adapter
   policy in the core and prevents independently reviewable connector Packs.
3. Keep one Lua VM alive behind bidirectional IPC while the host performs
   requests. This can preserve ordinary coroutine semantics, but introduces a
   longer-lived stateful protocol and a larger cancellation and cleanup
   surface.
4. Replay a bounded request/response transcript into a fresh runner. When the
   exact transcript ends, `lant.http.request` returns one typed pending request
   to the trusted parent. The parent authorizes and brokers it, appends the
   sanitized response, and invokes a new process from the beginning.

## Decision

Use option 4 for the V1 provider-source boundary. Lua sees a synchronous
`lant.http.request` function, while each runner step remains a fresh isolated
process and VM. The function exists only for a component with signed HTTP
permissions. A request must match exactly one component-local permission by
closed method set, canonical lowercase HTTPS host, and decoded path prefix;
overlapping signed rules are invalid.

Requests contain only an absolute URL, an allowlisted header map, and optional
canonical JSON. Responses contain only status, allowlisted metadata headers,
and canonical JSON. Provider credentials are injected by the trusted host and
are absent from Lua, runner messages, transcripts, checkpoints, diagnostics,
and events. The host remains responsible for preventing redirects or transport
behavior from escaping the authorized route.

The transcript is exact and linear. Every supplied exchange must be consumed
in order, every replayed request must equal the recorded request, and the final
successful invocation must consume the complete transcript. Repeating an
identical request in one invocation is treated as a cycle and rejected before
a second provider call. Exchange count and cumulative response size are
bounded.

Provider response bodies remain transient source custody. Remote preflight
persists only their digest, byte count, label, and the adapter's sparse
observation. Materialization refetches through the broker and must reproduce
that custody and observation before accepted Raw events can be decided.

## Consequences and verification

- adaptive pagination and child-route discovery work without giving the
  isolated process network or secret authority;
- runner crashes or cancellation leave no reusable interpreter state;
- the cost is deterministic re-execution proportional to the bounded number
  of provider exchanges;
- V1 provider components use JSON APIs; a future binary or streaming contract
  requires a separate reviewed capability rather than widening this one;
- manifest tests reject ambiguous HTTP authority;
- pure authorization tests reject nearby hosts, explicit ports, escaped path
  traversal, and unauthorized headers before transport;
- fake-provider tests cover sequential requests, fresh-VM replay, sparse
  preflight privacy, materialization exactness, route denial before broker
  invocation, and repeated-request cycle prevention; and
- replay tests require no Pack or provider availability because only accepted
  events are canonical.
