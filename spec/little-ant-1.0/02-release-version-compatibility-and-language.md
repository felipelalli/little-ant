# 2. Release and compatibility policy

## 2.1 Target version

- The redesign targets **Little Ant 1.0**, not v2.
- The current implementation remains v0 and the package remains `0.1.0.0`
  until the specification, implementation, tests, and documentation converge.
- The package should become `1.0.0.0` only after that convergence.
- The deterministic guided REPL is part of the 1.0 scope. It is not deferred
  to a later minor release.

## 2.2 No core compatibility aliases

Little Ant is not yet a multi-user production system. There is therefore no
requirement to preserve obsolete command names, lifecycle names, field names,
or shortcut aliases in the 1.0 core.

- The core must expose one exact, unambiguous vocabulary.
- Removed concepts should be removed instead of retained as aliases.
- The operator skill may understand informal or legacy natural language and
  map it to the one canonical core operation.
- Event migration may still need explicit upcasters. Wire-format migration is
  different from exposing ambiguous public aliases.

## 2.3 Language

Everything belonging to the product must be in English:

- commands and flags;
- shortcut letters and answer labels;
- CLI responses and error messages;
- canonical enum values;
- stored titles, descriptions, reasons, and other user data;
- README, specification, skill, command documentation, and examples.

The operator may converse in another language when appropriate, but it must
translate that conversation to canonical English before invoking or recording
Little Ant data. Messages addressed to third parties remain in the recipient's
language.

Verbatim non-English input may be retained as Raw or provenance so translation
never destroys information. It is not a second canonical title or searchable
domain value. When normalization occurs, the system should preserve the
original text, canonical English, and normalization author separately.

English canonicalization is also a prerequisite for consistent search and
duplicate suspicion. Exact enforcement in the dumb REPL, which cannot
reliably translate or prove a language on its own, remains open.
