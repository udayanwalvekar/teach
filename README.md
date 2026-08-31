# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into an evidence-backed learning module on your own computer. it uses the current chat, so you do not need to explain the project again.

Teach uses two separate agents. the first investigates the conversation and code, maps the real system, keeps relevant technologies, and removes noise. the second receives that validated map and creates the learning goal, worked example, simple diagram, and recall question.

## use it

finish building something, then type this in the same chat:

```text
teach
```

that is the whole prompt. the teaching level, relevant technologies, and honest system diagram are part of Teach itself.

each time `teach` starts, it checks a small public manifest on GitHub. if the teaching prompt changed, Teach verifies and caches the new prompt before continuing. if GitHub is unavailable, it immediately uses the last-known-good or bundled prompt. the check downloads only Teach's public instructions; it never sends the conversation, repository, paths, or lesson data to GitHub.

teach preserves `build-map.json`, `lesson.json`, and a standalone `index.html` under `~/teach-lessons/`. Teach generates and stores the finished lesson locally. It does not publish or host the page.

## install

Teach requires Python 3.9 or newer to build and serve the local lesson. on macOS, Linux, or WSL, paste one command:

```sh
curl -fsSL https://raw.githubusercontent.com/udayanwalvekar/teach/main/install.sh | sh
```

the installer detects Codex and Claude Code, installs Teach everywhere it is needed, and updates an existing installation. restart your coding agent after it finishes.

on Windows PowerShell, the same agent detection is available through:

```powershell
irm https://raw.githubusercontent.com/udayanwalvekar/teach/main/install.ps1 | iex
```

## update Teach

prompt improvements arrive automatically the next time someone types `teach`; no reinstall or restart is needed. set `TEACH_DISABLE_UPDATES=1` before starting the coding agent to stay on the prompt bundled with the installed version.

run the same install command again for new renderers, assets, installer behavior, or other executable changes. it refreshes every detected installation and keeps a timestamped backup of any replaced Claude Code skill.

## teaching style

teach uses a quiet black-and-white paper style: clear system type, thin rules, familiar controls, and no decorative color competing with the lesson.

every module is written for a curious 18-year-old and should take three to five minutes. it states the learning goal, shows one real before-and-after change, diagrams where each action happens, and ends with one unscored question. ordinary words come before technical terms. there are no quiz options, points, grades, playgrounds, or glossary popovers.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both coding agents: as a Codex plugin and as a personal Claude Code skill. Teach delegates investigation and learning design to two fresh agents, then uses dependency-free Python and a self-contained HTML shell for validation and rendering.

to publish a teaching-prompt change, edit `runtime/teach.md` or the Markdown files under `references/`, increment `PROMPT_VERSION` in `build_runtime_manifest.py`, then run that script and commit the refreshed manifest with the prompt. versions are monotonic, so an offline machine never replaces a newer installed prompt with an older cache. if a prompt requires new renderer or validator behavior, ship a new installer version and bump its bootstrap API instead of marking it compatible with the old executable bundle.
