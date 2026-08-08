# Slice packets

Each file in this directory is an implementation packet index. It names exact
canonical sources and acceptance evidence but does not restate normative
behavior. Generate the referenced blocks with S00's `spec-packet` tool before
working on a slice.

Slices are ordered by dependency, not by perceived product importance. S00 is
the only horizontal bootstrap. S01 onward must cross the dispatcher, domain
events, fold, projections, canonical envelope, dumb rendering, and tests.

Status vocabulary:

```text
planned      packet exists; implementation has not started
in_progress  failing acceptance evidence and current handoff identify the work
implemented owned dumb semantics pass but complete cross-surface evidence may remain
verified     every required evidence branch in the canonical flow row passes
```

No slice may be marked `verified` by prose, test count, an Allium analysis, or
a model review.
