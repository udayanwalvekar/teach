# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into a short visual explanation on your own computer. it uses the current chat, so you do not need to explain the project again.

every lesson answers three questions: **why was this needed?**, **what did i build?**, and **how does it work?** the final part follows one real action from the command you run to the result you see. only the technologies needed to understand that path are included, each in one plain sentence.

## use it

finish building something, then run Teach in the same chat:

- **Codex:** type `$teach`, or open the `/` command picker and choose **Teach**.
- **Claude Code:** type `/teach` after installing this skill into `~/.claude/skills/teach/`.

Teach requires Python 3 to build and serve its local lesson.

teach creates a standalone `index.html` under `~/teach-lessons/` and opens it on a local-only address. there is no account, cloud upload, tracking, or model API inside the page.

## install it from github

add the public marketplace, then install teach:

```sh
codex plugin marketplace add udayanwalvekar/teach
codex plugin add teach@teach
```

start a new thread after installation so Codex loads the skill into the command picker.

## teaching style

teach uses a quiet black-and-white paper style: clear system type, thin rules, familiar controls, and no decorative color competing with the lesson.

every explanation is written for a curious 18-year-old and should take about three minutes to understand. ordinary words come before technical terms. teach lessons do not include quizzes, playgrounds, scores, or glossary popovers.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both agents: as a Codex plugin and as a personal Claude Code skill. the lesson runtime is dependency-free Python plus a self-contained HTML shell.
