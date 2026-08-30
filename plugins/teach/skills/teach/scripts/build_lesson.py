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
    "builder_win",
    "minutes",
    "chat_context",
)
VISUAL_FIELDS = {
    "flow": "steps",
    "layers": "layers",
    "timeline": "steps",
    "map": "nodes",
}


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
    agent = meta.get("agent", "codex")
    require(agent in {"codex", "claude"}, "meta.agent must be codex or claude.")
    meta["agent"] = agent

    story = lesson.get("story")
    require(isinstance(story, list), "Missing array: story")
    require(3 <= len(story) <= 6, "story must contain 3 to 6 chapters.")
    chapter_ids: set[str] = set()
    for index, chapter in enumerate(story, start=1):
        require(isinstance(chapter, dict), f"story[{index - 1}] must be an object.")
        for field in ("id", "kicker", "title", "plain", "takeaway", "visual"):
            require(chapter.get(field), f"Chapter {index} is missing {field}.")
        require(chapter["id"] not in chapter_ids, f"Duplicate chapter id: {chapter['id']}")
        chapter_ids.add(chapter["id"])
        visual = chapter["visual"]
        require(isinstance(visual, dict), f"Chapter {index} visual must be an object.")
        visual_type = visual.get("type")
        require(
            visual_type in {"flow", "layers", "compare", "timeline", "map"},
            f"Chapter {index} has unsupported visual type: {visual_type}",
        )
        if visual_type == "compare":
            require(visual.get("left") and visual.get("right"), f"Chapter {index} compare visual needs left and right.")
        else:
            field = VISUAL_FIELDS[visual_type]
            require(isinstance(visual.get(field), list) and visual[field], f"Chapter {index} {visual_type} visual needs {field}.")
        if visual_type == "map":
            node_ids = {node.get("id") for node in visual["nodes"] if isinstance(node, dict)}
            require(None not in node_ids, f"Chapter {index} map nodes need ids.")
            for link in visual.get("links", []):
                require(
                    link.get("from") in node_ids and link.get("to") in node_ids,
                    f"Chapter {index} map link references an unknown node.",
                )
        analogy = chapter.get("analogy")
        if analogy:
            require(isinstance(analogy, dict), f"Chapter {index} analogy must be an object.")
            for field in ("title", "body", "mapping", "limit"):
                require(analogy.get(field), f"Chapter {index} analogy is missing {field}.")
            mapping = analogy["mapping"]
            require(isinstance(mapping, list) and mapping, f"Chapter {index} analogy.mapping must be a non-empty array.")
            for mapping_index, item in enumerate(mapping, start=1):
                require(
                    isinstance(item, dict) and item.get("familiar") and item.get("real"),
                    f"Chapter {index} analogy mapping {mapping_index} needs familiar and real.",
                )

    stack = lesson.get("stack")
    require(isinstance(stack, dict), "Missing object: stack")
    require(stack.get("summary"), "Missing stack.summary")
    stack_items = stack.get("items")
    require(isinstance(stack_items, list), "stack.items must be an array.")
    require(2 <= len(stack_items) <= 8, "stack.items must contain 2 to 8 technologies.")
    for index, item in enumerate(stack_items, start=1):
        require(isinstance(item, dict), f"Stack item {index} must be an object.")
        for field in ("layer", "technology", "role", "connection"):
            require(item.get(field), f"Stack item {index} is missing {field}.")

    concepts = lesson.get("concepts")
    require(isinstance(concepts, list) and concepts, "concepts must be a non-empty array.")
    for index, concept in enumerate(concepts, start=1):
        for field in ("term", "plain", "in_build"):
            require(concept.get(field), f"Concept {index} is missing {field}.")
        aliases = concept.get("aliases", [])
        require(isinstance(aliases, list), f"Concept {index} aliases must be an array.")
        require(all(isinstance(alias, str) and alias.strip() for alias in aliases), f"Concept {index} has an invalid alias.")

    playground = lesson.get("playground")
    require(isinstance(playground, dict), "Missing object: playground")
    scenarios = playground.get("scenarios")
    require(isinstance(scenarios, list), "playground.scenarios must be an array.")
    require(2 <= len(scenarios) <= 4, "playground.scenarios must contain 2 to 4 scenarios.")
    for index, scenario in enumerate(scenarios, start=1):
        for field in ("label", "tone", "headline", "body", "trace"):
            require(scenario.get(field), f"Playground scenario {index} is missing {field}.")
        require(scenario["tone"] in {"normal", "broken", "recovered"}, f"Scenario {index} has an unsupported tone.")

    quiz = lesson.get("quiz")
    require(isinstance(quiz, list), "Missing array: quiz")
    require(3 <= len(quiz) <= 5, "quiz must contain 3 to 5 questions.")
    for index, item in enumerate(quiz, start=1):
        for field in ("question", "choices", "explanation"):
            require(item.get(field), f"Quiz item {index} is missing {field}.")
        choices = item["choices"]
        require(isinstance(choices, list) and 2 <= len(choices) <= 5, f"Quiz item {index} needs 2 to 5 choices.")
        answer = item.get("answer")
        require(isinstance(answer, int) and 0 <= answer < len(choices), f"Quiz item {index} has an invalid answer index.")

    followups = lesson.get("followups")
    require(isinstance(followups, list), "Missing array: followups")
    require(3 <= len(followups) <= 5, "followups must contain 3 to 5 questions.")


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
