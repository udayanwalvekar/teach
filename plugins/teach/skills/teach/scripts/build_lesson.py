#!/usr/bin/env python3
"""Build a standalone Teach lesson from a JSON source file."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


PLACEHOLDER = "/*__TEACH_LESSON_DATA__*/"
REQUIRED_META = (
    "slug",
    "title",
    "subject",
    "one_liner",
    "minutes",
)
class LessonError(ValueError):
    """A lesson source cannot be built safely."""


def require(value: Any, message: str) -> None:
    if not value:
        raise LessonError(message)


def validate_lesson(lesson: dict[str, Any]) -> None:
    require(isinstance(lesson, dict), "The lesson source must be a JSON object.")

    meta = lesson.get("meta")
    require(isinstance(meta, dict), "Missing object: meta")
    for field in REQUIRED_META:
        require(meta.get(field), f"Missing meta.{field}")
    require(
        re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", str(meta["slug"])),
        "meta.slug must use lowercase letters, numbers, and single hyphens.",
    )
    require(
        isinstance(meta["minutes"], int) and 1 <= meta["minutes"] <= 60,
        "meta.minutes must be an integer from 1 to 60.",
    )
    story = lesson.get("story")
    require(isinstance(story, list), "Missing array: story")
    require(len(story) == 3, "story must contain exactly 3 chapters.")
    require(
        [chapter.get("id") for chapter in story if isinstance(chapter, dict)]
        == ["problem", "built", "works"],
        "story chapters must be problem, built, and works in that order.",
    )
    chapter_ids: set[str] = set()
    for index, chapter in enumerate(story, start=1):
        require(isinstance(chapter, dict), f"story[{index - 1}] must be an object.")
        for field in ("id", "kicker", "title", "plain", "takeaway"):
            require(chapter.get(field), f"Chapter {index} is missing {field}.")
        require(chapter["id"] not in chapter_ids, f"Duplicate chapter id: {chapter['id']}")
        chapter_ids.add(chapter["id"])
        if chapter["id"] != "works":
            require(
                "visual" not in chapter or chapter["visual"] is None,
                f"Chapter {index} must stay text-only.",
            )
            continue
        visual = chapter.get("visual")
        require(isinstance(visual, dict), "The works chapter needs a visual flow.")
        require(visual.get("type") == "flow", "The works chapter visual must be a flow.")
        steps = visual.get("steps")
        require(isinstance(steps, list) and 3 <= len(steps) <= 5, "The works flow must contain 3 to 5 steps.")
        for step_index, step in enumerate(steps, start=1):
            require(isinstance(step, dict), f"Flow step {step_index} must be an object.")
            require(step.get("label") and step.get("detail"), f"Flow step {step_index} needs label and detail.")
    technologies = lesson.get("technologies", [])
    require(isinstance(technologies, list), "technologies must be an array.")
    require(len(technologies) <= 6, "technologies must contain no more than 6 items.")
    for index, item in enumerate(technologies, start=1):
        require(isinstance(item, dict), f"Technology {index} must be an object.")
        for field in ("name", "explanation"):
            require(item.get(field), f"Technology {index} is missing {field}.")


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
    parser.add_argument("lesson", help="Path to the lesson JSON file")
    parser.add_argument("--output", help="Output directory or HTML file")
    args = parser.parse_args()

    source_path = Path(args.lesson).expanduser().resolve()
    if not source_path.is_file():
        print(f"Lesson source not found: {source_path}", file=sys.stderr)
        return 2

    try:
        lesson = json.loads(source_path.read_text(encoding="utf-8"))
        validate_lesson(lesson)
    except json.JSONDecodeError as error:
        print(f"Invalid JSON at line {error.lineno}, column {error.colno}: {error.msg}", file=sys.stderr)
        return 2
    except LessonError as error:
        print(f"Invalid lesson: {error}", file=sys.stderr)
        return 2

    template_path = Path(__file__).resolve().parent.parent / "assets" / "lesson-shell.html"
    template = template_path.read_text(encoding="utf-8")
    if template.count(PLACEHOLDER) != 1:
        print(f"Lesson shell must contain exactly one {PLACEHOLDER} marker.", file=sys.stderr)
        return 2

    output_path = resolve_output(args.output, lesson["meta"]["slug"])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    editable_source = output_path.parent / "lesson.json"
    editable_source.write_text(
        json.dumps(lesson, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    html = template.replace(PLACEHOLDER, safe_json_for_script(lesson))
    output_path.write_text(html, encoding="utf-8")

    print(f"Built lesson: {output_path}")
    print(f"Editable source: {editable_source}")
    print(f"Serve with: {Path(__file__).resolve().parent / 'serve_lesson.py'} {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
