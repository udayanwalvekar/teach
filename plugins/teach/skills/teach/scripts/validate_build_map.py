#!/usr/bin/env python3
"""Validate the evidence-backed handoff produced by Teach's Build Investigator."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ID_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
EVIDENCE_KINDS = {"conversation", "code", "documentation", "runtime", "test"}
SCOPE_MODES = {"full-stack", "single-area", "cross-cutting"}


class BuildMapError(ValueError):
    """A build map is incomplete or internally inconsistent."""


def require(value: Any, message: str) -> None:
    if not value:
        raise BuildMapError(message)


def require_text(value: Any, label: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{label} must be non-empty text.")
    return value


def require_object_fields(value: Any, fields: tuple[str, ...], label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object.")
    for field in fields:
        require(value.get(field), f"{label} is missing {field}.")
    return value


def require_id(value: Any, label: str) -> str:
    require(isinstance(value, str) and ID_PATTERN.fullmatch(value), f"{label} must be a lowercase hyphenated ID.")
    return value


def require_evidence_ids(value: Any, label: str, known_ids: set[str]) -> None:
    require(isinstance(value, list) and value, f"{label}.evidence_ids must be a non-empty array.")
    require(all(isinstance(item, str) for item in value), f"{label}.evidence_ids must contain strings.")
    missing = sorted(set(value) - known_ids)
    require(not missing, f"{label} references unknown evidence: {', '.join(missing)}.")


def evidence_id_set(build_map: dict[str, Any]) -> set[str]:
    return {item["id"] for item in build_map["evidence"]}


def area_by_id(build_map: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["id"]: item for item in build_map["scope"]["areas"]}


def technology_by_name(build_map: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["name"]: item for item in build_map["technologies"]}


def validate_build_map(build_map: dict[str, Any]) -> None:
    require(isinstance(build_map, dict), "The build map must be a JSON object.")
    for field in (
        "meta",
        "scope",
        "problem",
        "build",
        "system_flow",
        "technologies",
        "important_decisions",
        "discarded_details",
        "uncertainties",
        "evidence",
    ):
        require(field in build_map, f"The build map is missing {field}.")
    meta = require_object_fields(build_map.get("meta"), ("subject", "summary"), "meta")
    require_text(meta["subject"], "meta.subject")
    require_text(meta["summary"], "meta.summary")

    scope = require_object_fields(build_map.get("scope"), ("mode", "areas"), "scope")
    require(isinstance(scope["mode"], str) and scope["mode"] in SCOPE_MODES, "scope.mode must be full-stack, single-area, or cross-cutting.")
    areas = scope["areas"]
    require(isinstance(areas, list) and 1 <= len(areas) <= 6, "scope.areas must contain 1 to 6 areas.")
    area_ids: set[str] = set()
    for index, area in enumerate(areas, start=1):
        area = require_object_fields(area, ("id", "name", "role", "components"), f"Area {index}")
        area_id = require_id(area["id"], f"Area {index}.id")
        require_text(area["name"], f"Area {index}.name")
        require_text(area["role"], f"Area {index}.role")
        require(area_id not in area_ids, f"Duplicate area id: {area_id}.")
        area_ids.add(area_id)
        require(
            isinstance(area["components"], list)
            and 1 <= len(area["components"]) <= 6
            and all(isinstance(item, str) and item.strip() for item in area["components"]),
            f"Area {index}.components must contain 1 to 6 names.",
        )

    evidence = build_map.get("evidence")
    require(isinstance(evidence, list) and evidence, "evidence must be a non-empty array.")
    known_evidence: set[str] = set()
    for index, item in enumerate(evidence, start=1):
        item = require_object_fields(item, ("id", "kind", "source", "supports"), f"Evidence {index}")
        evidence_id = require_id(item["id"], f"Evidence {index}.id")
        require(evidence_id not in known_evidence, f"Duplicate evidence id: {evidence_id}.")
        require(isinstance(item["kind"], str) and item["kind"] in EVIDENCE_KINDS, f"Evidence {index}.kind is not supported.")
        require_text(item["source"], f"Evidence {index}.source")
        require_text(item["supports"], f"Evidence {index}.supports")
        known_evidence.add(evidence_id)

    for label in ("problem", "build"):
        section = require_object_fields(build_map.get(label), ("summary", "evidence_ids"), label)
        require_text(section["summary"], f"{label}.summary")
        require_evidence_ids(section["evidence_ids"], label, known_evidence)

    flow = build_map.get("system_flow")
    require(isinstance(flow, list) and 3 <= len(flow) <= 7, "system_flow must contain 3 to 7 steps.")
    flow_ids: set[str] = set()
    for index, step in enumerate(flow, start=1):
        step = require_object_fields(
            step,
            ("id", "label", "detail", "area_id", "evidence_ids"),
            f"Flow step {index}",
        )
        step_id = require_id(step["id"], f"Flow step {index}.id")
        require_text(step["label"], f"Flow step {index}.label")
        require_text(step["detail"], f"Flow step {index}.detail")
        require_text(step["area_id"], f"Flow step {index}.area_id")
        require(step_id not in flow_ids, f"Duplicate flow step id: {step_id}.")
        flow_ids.add(step_id)
        require(step["area_id"] in area_ids, f"Flow step {index} references an unknown area.")
        require_evidence_ids(step["evidence_ids"], f"Flow step {index}", known_evidence)

    technologies = build_map.get("technologies", [])
    require(isinstance(technologies, list) and len(technologies) <= 8, "technologies must contain no more than 8 items.")
    names: set[str] = set()
    for index, item in enumerate(technologies, start=1):
        item = require_object_fields(
            item,
            ("name", "job", "relevance", "evidence_ids"),
            f"Technology {index}",
        )
        require_text(item["name"], f"Technology {index}.name")
        require_text(item["job"], f"Technology {index}.job")
        require_text(item["relevance"], f"Technology {index}.relevance")
        require(item["name"] not in names, f"Duplicate technology: {item['name']}.")
        names.add(item["name"])
        require_evidence_ids(item["evidence_ids"], f"Technology {index}", known_evidence)

    decisions = build_map.get("important_decisions", [])
    require(isinstance(decisions, list), "important_decisions must be an array.")
    for index, item in enumerate(decisions, start=1):
        item = require_object_fields(item, ("summary", "evidence_ids"), f"Decision {index}")
        require_text(item["summary"], f"Decision {index}.summary")
        require_evidence_ids(item["evidence_ids"], f"Decision {index}", known_evidence)

    discarded = build_map.get("discarded_details", [])
    require(isinstance(discarded, list), "discarded_details must be an array.")
    for index, item in enumerate(discarded, start=1):
        item = require_object_fields(item, ("detail", "reason"), f"Discarded detail {index}")
        require_text(item["detail"], f"Discarded detail {index}.detail")
        require_text(item["reason"], f"Discarded detail {index}.reason")

    uncertainties = build_map.get("uncertainties", [])
    require(
        isinstance(uncertainties, list)
        and all(isinstance(item, str) and item.strip() for item in uncertainties),
        "uncertainties must be an array of non-empty strings.",
    )


def load_build_map(path: Path) -> dict[str, Any]:
    try:
        build_map = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise BuildMapError(f"Invalid JSON at line {error.lineno}, column {error.colno}: {error.msg}") from error
    validate_build_map(build_map)
    return build_map


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build_map", help="Path to build-map.json")
    args = parser.parse_args()
    path = Path(args.build_map).expanduser().resolve()
    if not path.is_file():
        print(f"Build map not found: {path}", file=sys.stderr)
        return 2
    try:
        build_map = load_build_map(path)
    except (OSError, BuildMapError) as error:
        print(f"Invalid build map: {error}", file=sys.stderr)
        return 2
    print(
        f"Valid build map: {len(build_map['scope']['areas'])} areas, "
        f"{len(build_map['system_flow'])} steps, {len(build_map['evidence'])} evidence items."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
