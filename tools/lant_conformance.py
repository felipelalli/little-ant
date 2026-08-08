#!/usr/bin/env python3
"""Little Ant specification packets and conformance audits.

This tool never interprets product prose. It discovers exact canonical blocks,
hashes their bytes, validates ownership and evidence metadata, and emits bounded
packets for one implementation slice.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence
from evidence_status import effective_coverage, verified_binding_errors


DEFINITION_RE = re.compile(
    r"^(?:(?:- \*\*)|(?:#{2,3} ))"
    r"(?P<identifier>(?:PRD|CAL|MOD|FED|IMP|FOC|WRK|UX|DAT|MIG|SCN)-[A-Z0-9-]+)\b"
)
RANGE_RE = re.compile(
    r"\b(?P<left>[A-Z]+-[A-Z0-9-]*\d+)\.\."
    r"(?P<right>[A-Z-]*\d+)\b"
)
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\((?P<target>[^)]+)\)")
HASH_PREFIX = "sha256:"
SLICE_RE = re.compile(r"^S(?:0[0-9]|1[01])$")


class ConformanceError(RuntimeError):
    pass


@dataclass(frozen=True)
class Definition:
    identifier: str
    catalog: str
    path: Path
    line: int
    block: str
    digest: str


@dataclass(frozen=True)
class FlowRow:
    gate: int
    flow: str
    references: str


def repository_root(start: Path | None = None) -> Path:
    current = (start or Path(__file__).resolve()).resolve()
    if current.is_file():
        current = current.parent
    for candidate in (current, *current.parents):
        if (candidate / "spec/little-ant-1.0.md").is_file():
            return candidate
    raise ConformanceError("could not locate repository root")


def sha256_text(text: str) -> str:
    return HASH_PREFIX + hashlib.sha256(text.encode("utf-8")).hexdigest()


def catalog_kind(path: Path, identifier: str) -> str:
    if path.name == "screen-catalog.md" and identifier.startswith("UX-"):
        return "screen"
    if identifier.startswith("SCN-"):
        return "scenario"
    return "rule"


def markdown_files(spec_root: Path) -> list[Path]:
    if spec_root.is_file():
        return [spec_root]
    return sorted(spec_root.rglob("*.md"))


def discover_catalog(spec_root: Path) -> dict[str, Definition]:
    found: dict[str, Definition] = {}
    duplicates: list[str] = []
    for path in markdown_files(spec_root):
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        starts: list[tuple[int, re.Match[str]]] = []
        for index, line in enumerate(lines):
            match = DEFINITION_RE.match(line)
            if match:
                starts.append((index, match))
        for position, (start, match) in enumerate(starts):
            end = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
            block = "".join(lines[start:end]).rstrip() + "\n"
            identifier = match.group("identifier")
            definition = Definition(
                identifier=identifier,
                catalog=catalog_kind(path, identifier),
                path=path,
                line=start + 1,
                block=block,
                digest=sha256_text(block),
            )
            if identifier in found:
                duplicates.append(
                    f"{identifier}: {found[identifier].path}:{found[identifier].line} "
                    f"and {path}:{start + 1}"
                )
            else:
                found[identifier] = definition
    if duplicates:
        raise ConformanceError("duplicate canonical definitions:\n" + "\n".join(duplicates))
    return found


def expand_range(token: str, identifiers: Mapping[str, Definition]) -> list[str]:
    match = RANGE_RE.fullmatch(token)
    if not match:
        raise ConformanceError(f"invalid canonical range: {token}")
    left = match.group("left")
    right = match.group("right")
    left_match = re.fullmatch(r"(?P<stem>.*?)(?P<number>\d+)", left)
    right_match = re.fullmatch(r"(?P<stem>[A-Z-]*)(?P<number>\d+)", right)
    if left_match is None or right_match is None:
        raise ConformanceError(f"invalid canonical range: {token}")
    stem = left_match.group("stem")
    right_stem = right_match.group("stem")
    if right_stem and not stem.endswith(right_stem):
        raise ConformanceError(f"ambiguous canonical range: {token}")
    first = int(left_match.group("number"))
    last = int(right_match.group("number"))
    if last < first:
        raise ConformanceError(f"descending canonical range: {token}")
    width = len(left_match.group("number"))
    expanded = [f"{stem}{number:0{width}d}" for number in range(first, last + 1)]
    missing = [identifier for identifier in expanded if identifier not in identifiers]
    if missing:
        raise ConformanceError(f"range {token} contains unknown IDs: {', '.join(missing)}")
    return expanded


def audit_ranges(paths: Iterable[Path], identifiers: Mapping[str, Definition]) -> None:
    failures: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for match in RANGE_RE.finditer(text):
            token = match.group(0)
            try:
                expand_range(token, identifiers)
            except ConformanceError as error:
                line = text.count("\n", 0, match.start()) + 1
                failures.append(f"{path}:{line}: {error}")
    if failures:
        raise ConformanceError("invalid canonical ranges:\n" + "\n".join(failures))


def parse_flow_rows(path: Path) -> list[FlowRow]:
    rows: list[FlowRow] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 5:
            raise ConformanceError(f"malformed flow row: {line}")
        rows.append(FlowRow(gate=int(cells[0]), flow=cells[1], references=cells[2]))
    duplicate_keys = _duplicates((row.gate, row.flow) for row in rows)
    if duplicate_keys:
        raise ConformanceError(f"duplicate canonical flow rows: {sorted(duplicate_keys)}")
    return rows


def _duplicates(values: Iterable[object]) -> set[object]:
    seen: set[object] = set()
    duplicates: set[object] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return duplicates


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def audit_flow_coverage(canonical: Sequence[FlowRow], coverage_path: Path) -> list[dict[str, str]]:
    rows = read_tsv(coverage_path)
    required_fields = {"gate", "flow", "owner_slice", "status", "evidence"}
    if rows and not required_fields.issubset(rows[0]):
        raise ConformanceError(f"coverage TSV lacks fields: {sorted(required_fields)}")
    canonical_keys = {(str(row.gate), row.flow) for row in canonical}
    actual_keys = {(row["gate"], row["flow"]) for row in rows}
    duplicate_keys = _duplicates((row["gate"], row["flow"]) for row in rows)
    errors: list[str] = []
    if duplicate_keys:
        errors.append(f"duplicate coverage rows: {sorted(duplicate_keys)}")
    missing = canonical_keys - actual_keys
    unknown = actual_keys - canonical_keys
    if missing:
        errors.append(f"missing flow ownership: {sorted(missing)}")
    if unknown:
        errors.append(f"unknown flow ownership: {sorted(unknown)}")
    for row in rows:
        if not SLICE_RE.fullmatch(row["owner_slice"]):
            errors.append(f"invalid owner for {row['flow']}: {row['owner_slice']}")
        if row["status"] not in {"planned", "implemented", "verified"}:
            errors.append(f"invalid status for {row['flow']}: {row['status']}")
        if row["status"] == "verified" and row["evidence"] in {"", "-"}:
            errors.append(f"verified flow lacks evidence: {row['flow']}")
    if errors:
        raise ConformanceError("flow coverage audit failed:\n" + "\n".join(errors))
    return rows


def audit_owners(catalog: Mapping[str, Definition], owners_path: Path) -> None:
    rows = read_tsv(owners_path)
    required = {"catalog", "prefix", "owner_slice", "rationale"}
    if rows and not required.issubset(rows[0]):
        raise ConformanceError(f"owner TSV lacks fields: {sorted(required)}")
    failures: list[str] = []
    matched_rows: set[int] = set()
    for definition in catalog.values():
        prefix = definition.identifier.split("-", 1)[0]
        matches = [
            (index, row)
            for index, row in enumerate(rows)
            if row["catalog"] == definition.catalog and row["prefix"] == prefix
        ]
        if len(matches) != 1:
            failures.append(
                f"{definition.identifier} ({definition.catalog}) has {len(matches)} owners"
            )
            continue
        index, row = matches[0]
        matched_rows.add(index)
        if not SLICE_RE.fullmatch(row["owner_slice"]):
            failures.append(f"invalid owner {row['owner_slice']} for {definition.identifier}")
        if not row["rationale"].strip():
            failures.append(f"owner rationale missing for {definition.identifier}")
    unused = [rows[index] for index in range(len(rows)) if index not in matched_rows]
    if unused:
        failures.append(f"owner selectors match no canonical ID: {unused}")
    if failures:
        raise ConformanceError("catalog ownership audit failed:\n" + "\n".join(failures))


def required_obligations(definition: Definition) -> set[str]:
    if definition.catalog != "rule":
        return set()
    lowered = definition.block.lower()
    title = definition.block.splitlines()[0].lower()
    obligations: set[str] = set()
    if any(term in lowered for term in ("must not", "cannot", " never ", " no ")) or "— no " in title:
        obligations.add("negative")
    if any(term in lowered for term in (" before ", " approval", " consent", " gate", " precondition")):
        obligations.add("gate")
    if any(term in lowered for term in (" if ", " when ", " unless ", " only ", " otherwise ")):
        obligations.add("boundary")
    return obligations


def validate_descriptor(descriptor: Mapping[str, object], catalog: Mapping[str, Definition]) -> None:
    evidence_id = descriptor.get("evidence_id")
    if not isinstance(evidence_id, str) or not evidence_id:
        raise ConformanceError("evidence descriptor lacks evidence_id")
    referenced: list[str] = []
    for field in ("rules", "screens"):
        values = descriptor.get(field, [])
        if not isinstance(values, list) or not all(isinstance(item, str) for item in values):
            raise ConformanceError(f"{evidence_id}: {field} must be a string list")
        referenced.extend(values)
    unknown = [identifier for identifier in referenced if identifier not in catalog]
    if unknown:
        raise ConformanceError(f"{evidence_id}: unknown IDs: {unknown}")
    hashes = descriptor.get("spec_hashes", {})
    if not isinstance(hashes, dict):
        raise ConformanceError(f"{evidence_id}: spec_hashes must be an object")
    stale = [
        identifier
        for identifier in referenced
        if hashes.get(identifier) != catalog[identifier].digest
    ]
    if stale:
        raise ConformanceError(
            f"{evidence_id}: stale or missing hashes for {stale}; verified evidence must be demoted"
        )
    declared = descriptor.get("obligations", [])
    if not isinstance(declared, list) or not all(isinstance(item, str) for item in declared):
        raise ConformanceError(f"{evidence_id}: obligations must be a string list")
    required = set().union(*(required_obligations(catalog[item]) for item in referenced))
    missing = required - set(declared)
    if missing:
        raise ConformanceError(f"{evidence_id}: missing obligations: {sorted(missing)}")


def load_evidence(path: Path) -> list[dict[str, object]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list) or not all(isinstance(item, dict) for item in data):
        raise ConformanceError("evidence.json must contain one array of objects")
    duplicate_ids = _duplicates(item.get("evidence_id") for item in data)
    if duplicate_ids:
        raise ConformanceError(f"duplicate evidence IDs: {sorted(duplicate_ids)}")
    return data


def audit_evidence(path: Path, catalog: Mapping[str, Definition]) -> list[dict[str, object]]:
    evidence = load_evidence(path)
    for descriptor in evidence:
        validate_descriptor(descriptor, catalog)
    return evidence


def audit_errata(path: Path) -> None:
    rows = read_tsv(path)
    allowed = {"editorial", "normative"}
    failures: list[str] = []
    for index, row in enumerate(rows, start=2):
        if row.get("classification") not in allowed:
            failures.append(f"{path}:{index}: invalid classification")
        for field in ("old_hash", "new_hash"):
            value = row.get(field, "")
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", value):
                failures.append(f"{path}:{index}: invalid {field}")
        for field in ("affected_ids", "reviewed_by", "rationale"):
            if not row.get(field, "").strip():
                failures.append(f"{path}:{index}: missing {field}")
    if failures:
        raise ConformanceError("spec errata audit failed:\n" + "\n".join(failures))


def audit_markdown_links(root: Path) -> None:
    paths = [root / "README.md", *sorted((root / "spec").rglob("*.md")), *sorted((root / "implementation").rglob("*.md"))]
    failures: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for match in MARKDOWN_LINK_RE.finditer(text):
            target = match.group("target").strip().strip("<>")
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            target_path = target.split("#", 1)[0].split("?", 1)[0]
            if not target_path:
                continue
            resolved = (path.parent / target_path).resolve()
            if not resolved.exists():
                line = text.count("\n", 0, match.start()) + 1
                failures.append(f"{path.relative_to(root)}:{line}: missing {target}")
    if failures:
        raise ConformanceError("Markdown link audit failed:\n" + "\n".join(failures))


def rejected_commands(root: Path) -> set[str]:
    text = (root / "spec/little-ant-1.0/command-catalog.md").read_text(encoding="utf-8")
    marker = "## Explicitly rejected vocabulary"
    section = text.split(marker, 1)[1]
    return {token for token in re.findall(r"`(/[^`]+)`", section)}


def legacy_terms(root: Path) -> set[str]:
    text = (root / "spec/little-ant-1.0/01-product-language-and-scope.md").read_text(encoding="utf-8")
    table = text.split("| Rejected or legacy term |", 1)[1].split("\n\n", 1)[0]
    terms: set[str] = set()
    for line in table.splitlines()[2:]:
        cells = [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]
        if cells and cells[0]:
            terms.add(cells[0])
    return terms


def load_vocabulary_allowlist(path: Path) -> list[dict[str, str]]:
    return read_tsv(path)


def vocabulary_violations_for_text(
    path: str,
    text: str,
    commands: set[str],
    terms: set[str],
    allowlist: Sequence[Mapping[str, str]],
    code: bool,
) -> list[str]:
    violations: list[str] = []

    def allowed(token: str) -> bool:
        return any(
            re.fullmatch(row["path_regex"], path)
            and (row["token"] == "*" or row["token"].casefold() == token.casefold())
            and row["reason"].strip()
            for row in allowlist
        )

    for command in sorted(commands, key=len, reverse=True):
        if re.search(re.escape(command) + r"(?![-A-Za-z0-9])", text) and not allowed(command):
            violations.append(f"{path}: rejected command {command}")
    if code:
        for term in sorted(terms):
            if re.search(rf"(?<![A-Za-z0-9]){re.escape(term)}(?![A-Za-z0-9])", text, re.IGNORECASE) and not allowed(term):
                violations.append(f"{path}: rejected public identifier {term}")
    if re.search(r"^\s*executable\s+la\s*$", text, re.MULTILINE) and not allowed("executable la"):
        violations.append(f"{path}: retired executable la")
    return violations


def audit_vocabulary(root: Path) -> None:
    commands = rejected_commands(root)
    terms = legacy_terms(root)
    allowlist = load_vocabulary_allowlist(root / "conformance/vocabulary-allowlist.tsv")
    candidates = [root / "README.md", root / "little-ant.cabal", root / "flake.nix"]
    for directory in ("src", "app", "test", "skills", "commands", "packs", "web"):
        base = root / directory
        if base.exists():
            candidates.extend(path for path in base.rglob("*") if path.is_file())
    failures: list[str] = []
    code_suffixes = {".hs", ".lhs", ".lua", ".js", ".ts", ".json", ".yaml", ".yml", ".cabal", ".nix"}
    text_suffixes = code_suffixes | {".md", ".py"}
    for path in sorted(set(candidates)):
        if path.suffix not in text_suffixes and path.name not in {"little-ant.cabal", "flake.nix"}:
            continue
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        failures.extend(
            vocabulary_violations_for_text(
                relative,
                text,
                commands,
                terms,
                allowlist,
                path.suffix in code_suffixes or path.name in {"little-ant.cabal", "flake.nix"},
            )
        )
    if failures:
        raise ConformanceError("public vocabulary audit failed:\n" + "\n".join(failures))


def build_packet(root: Path, identifiers: Sequence[str], flows: Sequence[str]) -> str:
    catalog = discover_catalog(root / "spec")
    canonical_flows = parse_flow_rows(root / "spec/little-ant-1.0/ux/flow-coverage.md")
    flow_map = {row.flow: row for row in canonical_flows}
    unknown = [identifier for identifier in identifiers if identifier not in catalog]
    unknown_flows = [flow for flow in flows if flow not in flow_map]
    if unknown or unknown_flows:
        raise ConformanceError(f"unknown packet references: IDs={unknown}, flows={unknown_flows}")
    parts = ["# Exact Little Ant specification packet", ""]
    for identifier in identifiers:
        definition = catalog[identifier]
        relative = definition.path.relative_to(root)
        parts.extend(
            [
                f"## {identifier}",
                "",
                f"Source: `{relative}:{definition.line}`",
                f"Hash: `{definition.digest}`",
                "",
                definition.block.rstrip(),
                "",
            ]
        )
    for flow in flows:
        row = flow_map[flow]
        parts.extend(
            [
                f"## Flow: {flow}",
                "",
                "Source: `spec/little-ant-1.0/ux/flow-coverage.md`",
                "",
                f"| {row.gate} | {row.flow} | {row.references} |",
                "",
            ]
        )
    return "\n".join(parts).rstrip() + "\n"


def coverage_report(root: Path) -> dict[str, object]:
    catalog = discover_catalog(root / "spec")
    flows = parse_flow_rows(root / "spec/little-ant-1.0/ux/flow-coverage.md")
    coverage = audit_flow_coverage(flows, root / "implementation/coverage.tsv")
    evidence = load_evidence(root / "conformance/evidence.json")
    effective = effective_coverage(coverage, evidence, lambda descriptor: validate_descriptor(descriptor, catalog))
    counts = {status: sum(row["status"] == status for row in effective) for status in ("planned", "implemented", "verified")}
    return {
        "schema": "little-ant/conformance-coverage@1",
        "catalog": {
            "rules": sum(item.catalog == "rule" for item in catalog.values()),
            "screens": sum(item.catalog == "screen" for item in catalog.values()),
            "scenarios": sum(item.catalog == "scenario" for item in catalog.values()),
            "flows": len(flows),
        },
        "flow_status": counts,
        "evidence_count": len(evidence),
        "flows": effective,
    }


def full_audit(root: Path) -> dict[str, object]:
    catalog = discover_catalog(root / "spec")
    audit_ranges(
        [*markdown_files(root / "spec"), *markdown_files(root / "implementation")],
        catalog,
    )
    audit_markdown_links(root)
    audit_owners(catalog, root / "conformance/catalog-owners.tsv")
    flows = parse_flow_rows(root / "spec/little-ant-1.0/ux/flow-coverage.md")
    coverage = audit_flow_coverage(flows, root / "implementation/coverage.tsv")
    evidence = audit_evidence(root / "conformance/evidence.json", catalog)
    binding_failures = verified_binding_errors(coverage, evidence)
    if binding_failures:
        raise ConformanceError("verified evidence binding failed:\n" + "\n".join(binding_failures))
    audit_errata(root / "conformance/spec-hash-errata.tsv")
    audit_vocabulary(root)
    return {
        "definitions": len(catalog),
        "rules": sum(item.catalog == "rule" for item in catalog.values()),
        "screens": sum(item.catalog == "screen" for item in catalog.values()),
        "scenarios": sum(item.catalog == "scenario" for item in catalog.values()),
        "flows": len(flows),
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--root", type=Path, help="repository root")
    subcommands = result.add_subparsers(dest="command", required=True)

    packet = subcommands.add_parser("packet", help="emit exact canonical blocks")
    packet.add_argument("identifiers", nargs="*")
    packet.add_argument("--flow", action="append", default=[])
    packet.add_argument("--output", type=Path)

    subcommands.add_parser("audit", help="run every conformance audit")

    coverage = subcommands.add_parser("coverage", help="emit machine-readable coverage")
    coverage.add_argument("--output", type=Path)

    hash_command = subcommands.add_parser("hash", help="print canonical block hashes")
    hash_command.add_argument("identifiers", nargs="+")

    subcommands.add_parser("vocabulary", help="run only the public vocabulary guard")
    return result


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    root = (arguments.root or repository_root()).resolve()
    try:
        if arguments.command == "packet":
            content = build_packet(root, arguments.identifiers, arguments.flow)
            if arguments.output:
                arguments.output.write_text(content, encoding="utf-8")
            else:
                sys.stdout.write(content)
        elif arguments.command == "audit":
            print(json.dumps(full_audit(root), sort_keys=True))
        elif arguments.command == "coverage":
            content = json.dumps(coverage_report(root), indent=2, sort_keys=True) + "\n"
            if arguments.output:
                arguments.output.write_text(content, encoding="utf-8")
            else:
                sys.stdout.write(content)
        elif arguments.command == "hash":
            catalog = discover_catalog(root / "spec")
            for identifier in arguments.identifiers:
                if identifier not in catalog:
                    raise ConformanceError(f"unknown canonical ID: {identifier}")
                print(f"{identifier}\t{catalog[identifier].digest}")
        elif arguments.command == "vocabulary":
            audit_vocabulary(root)
            print("public vocabulary: clean")
    except (ConformanceError, OSError, json.JSONDecodeError) as error:
        print(f"conformance error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
