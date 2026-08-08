"""Mechanical evidence-to-flow status policy for conformance reports."""

from __future__ import annotations

from typing import Callable, Mapping, Sequence


def evidence_ids(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip() and item.strip() != "-"]


def effective_coverage(
    rows: Sequence[Mapping[str, str]],
    evidence: Sequence[Mapping[str, object]],
    validate: Callable[[Mapping[str, object]], None],
) -> list[dict[str, object]]:
    descriptors = {str(item.get("evidence_id")): item for item in evidence}
    health: dict[str, str | None] = {}
    for identifier, descriptor in descriptors.items():
        try:
            validate(descriptor)
        except Exception as error:  # the caller owns the typed validation error
            health[identifier] = str(error)
        else:
            health[identifier] = None

    result: list[dict[str, object]] = []
    for source in rows:
        row: dict[str, object] = dict(source)
        if source["status"] == "verified":
            identifiers = evidence_ids(source["evidence"])
            reasons = []
            for identifier in identifiers:
                if identifier not in descriptors:
                    reasons.append(f"missing evidence {identifier}")
                elif health[identifier] is not None:
                    reasons.append(f"{identifier}: {health[identifier]}")
            if not identifiers:
                reasons.append("verified flow has no evidence IDs")
            if reasons:
                row["declared_status"] = "verified"
                row["status"] = "implemented"
                row["demotion_reasons"] = reasons
        result.append(row)
    return result


def verified_binding_errors(
    rows: Sequence[Mapping[str, str]], evidence: Sequence[Mapping[str, object]]
) -> list[str]:
    known = {str(item.get("evidence_id")) for item in evidence}
    failures: list[str] = []
    for row in rows:
        if row["status"] != "verified":
            continue
        identifiers = evidence_ids(row["evidence"])
        if not identifiers:
            failures.append(f"{row['flow']}: verified without evidence IDs")
            continue
        missing = [identifier for identifier in identifiers if identifier not in known]
        if missing:
            failures.append(f"{row['flow']}: unknown evidence IDs {missing}")
    return failures
