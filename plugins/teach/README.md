# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into an evidence-backed learning module on your own computer. it uses the current chat, so you do not need to explain the project again.

Teach uses two separate agents. the first investigates the conversation and code, maps the real system, keeps relevant technologies, and removes noise. the second receives that validated map and creates the learning goal, worked example, simple diagram, and recall question.

## use it

finish building something, then run Teach in the same chat:

- **Codex:** type `$teach`, or open the `/` command picker and choose **Teach**.
- **Claude Code:** type `/teach` after installing this skill into `~/.claude/skills/teach/`.

Teach requires Python 3.9 or newer to build and serve its local lesson.

teach preserves `build-map.json`, `lesson.json`, and a standalone `index.html` under `~/teach-lessons/`. Teach generates and stores the finished lesson locally. It does not publish or host the page.

## install it from github

add the public marketplace, then install teach:

```sh
codex plugin marketplace add udayanwalvekar/teach
codex plugin add teach@teach
```

start a new thread after installation so Codex loads the skill into the command picker.

## update Teach

Codex keeps the marketplace snapshot and the installed plugin as separate copies. refresh the marketplace, replace the installed copy, then start a new thread:

```sh
codex plugin marketplace upgrade teach
codex plugin remove teach@teach
codex plugin add teach@teach
```

Claude Code users update by running the current one-command installer from the repository README again. the installer backs up the existing skill before replacing it; restart Claude Code afterward.

## teaching style

teach uses a quiet black-and-white paper style: clear system type, thin rules, familiar controls, and no decorative color competing with the lesson.

every module is written for a curious 18-year-old and should take three to five minutes. it states the learning goal, shows one real before-and-after change, diagrams where each action happens, and ends with one unscored question. ordinary words come before technical terms. there are no quiz options, points, grades, playgrounds, or glossary popovers.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both coding agents: as a Codex plugin and as a personal Claude Code skill. Teach delegates investigation and learning design to two fresh agents, then uses dependency-free Python and a self-contained HTML shell for validation and rendering.
