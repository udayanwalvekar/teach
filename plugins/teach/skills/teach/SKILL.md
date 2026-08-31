---
name: teach
description: Turn the product, feature, automation, or technical system just built or discussed in the current chat into an evidence-backed local learning module for a non-developer. Use when the builder says "teach", explicitly invokes Teach, or asks to understand what they just built; do not use for ordinary implementation, code documentation, or generic explanations unrelated to the active build.
---

# Teach

The single word `teach` is a complete request. Do not ask the builder to restate the teaching level, technologies, or system boundaries.

Before investigating the build, load Teach's current teaching instructions:

1. Treat the directory containing this `SKILL.md` as `<teach-skill-root>`.
2. Run `<teach-skill-root>/scripts/resolve_runtime.py` with Python 3.9 or newer (`python3` on macOS/Linux, or `py -3`/`python` on Windows).
3. Read the absolute Markdown path printed by the resolver and follow it as the active Teach prompt. Resolve its Markdown links relative to that returned file. Continue resolving scripts and assets from `<teach-skill-root>`.

The resolver makes one short request for Teach's public prompt manifest, downloads a changed prompt only after verifying its SHA-256 hashes, and otherwise uses the verified cache. If GitHub is unavailable or an update is invalid, it returns the last-known-good prompt or this installation's bundled prompt. It never uploads the conversation, repository, paths, or lesson data.

Set `TEACH_DISABLE_UPDATES=1` to skip the network check and always use the prompt bundled with this installation. Updating renderer scripts, assets, or other executable behavior still requires rerunning the Teach installer.
