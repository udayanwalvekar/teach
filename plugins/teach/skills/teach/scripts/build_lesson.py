#!/usr/bin/env python3
"""Build a standalone Teach module from a lesson and validated build map."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from validate_build_map import (
    BuildMapError,
    area_by_id,
    evidence_id_set,
    load_build_map,
    technology_by_name,
)


PLACEHOLDER = "/*__TEACH_LESSON_DATA__*/"
REQUIRED_META = ("slug", "title", "subject", "one_liner", "learning_goal", "minutes")


class LessonError(ValueError):
    """A lesson source cannot be built safely."""


def require(value: Any, message: str) -> None:
    if not value:
        raise LessonError(message)


def require_text(value: Any, label: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{label} must be non-empty text.")
    return value


def require_evidence_ids(value: Any, label: str, known_ids: set[str]) -> None:
    require(isinstance(value, list) and value, f"{label}.evidence_ids must be a non-empty array.")
    require(all(isinstance(item, str) for item in value), f"{label}.evidence_ids must contain strings.")
    missing = sorted(set(value) - known_ids)
    require(not missing, f"{label} references unknown evidence: {', '.join(missing)}.")


def validate_lesson(lesson: dict[str, Any], build_map: dict[str, Any]) -> None:
    require(isinstance(lesson, dict), "The lesson source must be a JSON object.")
    require("technologies" not in lesson, "Technologies must be explained inside flow steps, not in a top-level list.")

    meta = lesson.get("meta")
    require(isinstance(meta, dict), "Missing object: meta")
    for field in REQUIRED_META:
        require(field in meta, f"Missing meta.{field}")
    for field in ("slug", "title", "subject", "one_liner", "learning_goal"):
        require_text(meta[field], f"meta.{field}")
    require(
        re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", meta["slug"]),
        "meta.slug must use lowercase letters, numbers, and single hyphens.",
    )
    require(
        isinstance(meta["minutes"], int)
        and not isinstance(meta["minutes"], bool)
        and 1 <= meta["minutes"] <= 10,
        "meta.minutes must be an integer from 1 to 10.",
    )
    require(meta["subject"] == build_map["meta"]["subject"], "meta.subject must match the validated build map.")

    known_evidence = evidence_id_set(build_map)
    areas = area_by_id(build_map)
    technologies = technology_by_name(build_map)

    story = lesson.get("story")
    require(isinstance(story, list), "Missing array: story")
    require(len(story) == 3, "story must contain exactly 3 chapters.")
    require(
        [chapter.get("id") for chapter in story if isinstance(chapter, dict)] == ["problem", "built", "works"],
        "story chapters must be problem, built, and works in that order.",
    )

    for index, chapter in enumerate(story, start=1):
        require(isinstance(chapter, dict), f"story[{index - 1}] must be an object.")
        for field in ("id", "kicker", "title", "plain", "takeaway", "evidence_ids"):
            require(field in chapter, f"Chapter {index} is missing {field}.")
        for field in ("id", "kicker", "title", "plain", "takeaway"):
            require_text(chapter[field], f"Chapter {index}.{field}")
        require_evidence_ids(chapter["evidence_ids"], f"Chapter {index}", known_evidence)

        if chapter["id"] == "problem":
            require("example" not in chapter and "visual" not in chapter, "The problem chapter must stay text-only.")
            continue

        if chapter["id"] == "built":
            require("visual" not in chapter, "The built chapter uses a worked example, not a diagram.")
            example = chapter.get("example")
            require(isinstance(example, dict), "The built chapter needs a worked example.")
            for field in ("before", "after", "insight", "evidence_ids"):
                require(field in example, f"The worked example is missing {field}.")
            for field in ("before", "after", "insight"):
                require_text(example[field], f"Worked example.{field}")
            require_evidence_ids(example["evidence_ids"], "Worked example", known_evidence)
            continue

        require("example" not in chapter, "The works chapter cannot contain a second worked example.")
        visual = chapter.get("visual")
        require(isinstance(visual, dict), "The works chapter needs a visual flow.")
        require(visual.get("type") == "flow", "The works chapter visual must be a flow.")
        require_text(visual.get("title"), "Works flow.title")
        steps = visual.get("steps")
        require(isinstance(steps, list) and 3 <= len(steps) <= 5, "The works flow must contain 3 to 5 steps.")
        for step_index, step in enumerate(steps, start=1):
            require(isinstance(step, dict), f"Flow step {step_index} must be an object.")
            for field in ("label", "detail", "area_id", "area_name", "evidence_ids"):
                require(field in step, f"Flow step {step_index} is missing {field}.")
            for field in ("label", "detail", "area_id", "area_name"):
                require_text(step[field], f"Flow step {step_index}.{field}")
            area = areas.get(step["area_id"])
            require(area, f"Flow step {step_index} references an unknown area.")
            require(step["area_name"] == area["name"], f"Flow step {step_index}.area_name must match the build map.")
            require_evidence_ids(step["evidence_ids"], f"Flow step {step_index}", known_evidence)
            technology = step.get("technology")
            if technology is not None:
                require(isinstance(technology, dict), f"Flow step {step_index}.technology must be an object.")
                require_text(technology.get("name"), f"Flow step {step_index}.technology.name")
                require_text(technology.get("explanation"), f"Flow step {step_index}.technology.explanation")
                require(technology["name"] in technologies, f"Flow step {step_index} uses a technology absent from the build map.")
                require_evidence_ids(technology.get("evidence_ids"), f"Flow step {step_index}.technology", known_evidence)
                technology_evidence = set(technology["evidence_ids"])
                mapped_evidence = set(technologies[technology["name"]]["evidence_ids"])
                step_evidence = set(step["evidence_ids"])
                require(
                    technology_evidence <= mapped_evidence,
                    f"Flow step {step_index}.technology cites evidence not attached to that technology in the build map.",
                )
                require(
                    technology_evidence <= step_evidence,
                    f"Flow step {step_index}.technology evidence must also support the flow step.",
                )

    check = lesson.get("check")
    require(isinstance(check, dict), "Missing object: check")
    for field in ("question", "answer", "why", "evidence_ids"):
        require(field in check, f"check is missing {field}.")
    for field in ("question", "answer", "why"):
        require_text(check[field], f"check.{field}")
    require_evidence_ids(check["evidence_ids"], "check", known_evidence)


def safe_json_for_script(value: dict[str, Any]) -> str:
    rendered = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return (
        rendered.replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("&", "\\u0026")
        .replace("\u2028", "\\u2028")
        .replace("\u2029", "\\u2029")
    )


def resolve_output(raw_output: str | None, slug: str) -> Path:
    if raw_output:
        output = Path(raw_output).expanduser().resolve()
        return output if output.suffix.lower() == ".html" else output / "index.html"
    return Path.home() / "teach-lessons" / slug / "index.html"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lesson", help="Path to lesson.json")
    parser.add_argument("--build-map", required=True, help="Path to the validated build-map.json")
    parser.add_argument("--output", help="Output directory or HTML file")
    args = parser.parse_args()

    source_path = Path(args.lesson).expanduser().resolve()
    map_path = Path(args.build_map).expanduser().resolve()
    if not source_path.is_file():
        print(f"Lesson source not found: {source_path}", file=sys.stderr)
        return 2
    if not map_path.is_file():
        print(f"Build map not found: {map_path}", file=sys.stderr)
        return 2

    try:
        build_map = load_build_map(map_path)
        lesson = json.loads(source_path.read_text(encoding="utf-8"))
        validate_lesson(lesson, build_map)
    except json.JSONDecodeError as error:
        print(f"Invalid lesson JSON at line {error.lineno}, column {error.colno}: {error.msg}", file=sys.stderr)
        return 2
    except (BuildMapError, LessonError) as error:
        print(f"Invalid lesson: {error}", file=sys.stderr)
        return 2

    template_path = Path(__file__).resolve().parent.parent / "assets" / "lesson-shell.html"
    template = template_path.read_text(encoding="utf-8")
    if template.count(PLACEHOLDER) != 1:
        print(f"Lesson shell must contain exactly one {PLACEHOLDER} marker.", file=sys.stderr)
        return 2

    output_path = resolve_output(args.output, lesson["meta"]["slug"])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    (output_path.parent / "lesson.json").write_text(json.dumps(lesson, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output_path.parent / "build-map.json").write_text(json.dumps(build_map, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output_path.write_text(template.replace(PLACEHOLDER, safe_json_for_script(lesson)), encoding="utf-8")

    print(f"Built lesson: {output_path}")
    print(f"Evidence map: {output_path.parent / 'build-map.json'}")
    print(f"Editable lesson: {output_path.parent / 'lesson.json'}")
    print(f"Serve with: {Path(__file__).resolve().parent / 'serve_lesson.py'} {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
