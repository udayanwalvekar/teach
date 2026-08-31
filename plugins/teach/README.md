# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into an evidence-backed learning module on your own computer. it uses the current chat, so you do not need to explain the project again.

Teach uses two separate agents. the first investigates the conversation and code, maps the real system, keeps relevant technologies, and removes noise. the second receives that validated map and creates the learning goal, worked example, simple diagram, and recall question.

## use it

finish building something, then type `teach` in the same chat. that is the whole prompt; the teaching rules are already part of the skill.

Teach requires Python 3.9 or newer to build and serve its local lesson.

teach preserves `build-map.json`, `lesson.json`, and a standalone `index.html` under `~/teach-lessons/`. Teach generates and stores the finished lesson locally. It does not publish or host the page.

## install

```sh
curl -fsSL https://raw.githubusercontent.com/udayanwalvekar/teach/main/install.sh | sh
```

the installer detects Codex and Claude Code and installs or updates Teach for every detected agent. restart the agent after installation.

## update Teach

teaching-prompt improvements are checked, verified, and cached automatically whenever `teach` starts. if GitHub is unavailable, Teach uses the last-known-good or bundled prompt. this check never sends the conversation or project data to GitHub. set `TEACH_DISABLE_UPDATES=1` to stay on the bundled prompt.

run the same install command again, then restart the agent, when Teach ships new renderer scripts, assets, or other executable behavior.

## teaching style

teach uses a quiet black-and-white paper style: clear system type, thin rules, familiar controls, and no decorative color competing with the lesson.

every module is written for a curious 18-year-old and should take three to five minutes. it states the learning goal, shows one real before-and-after change, diagrams where each action happens, and ends with one unscored question. ordinary words come before technical terms. there are no quiz options, points, grades, playgrounds, or glossary popovers.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both coding agents: as a Codex plugin and as a personal Claude Code skill. Teach delegates investigation and learning design to two fresh agents, then uses dependency-free Python and a self-contained HTML shell for validation and rendering.
