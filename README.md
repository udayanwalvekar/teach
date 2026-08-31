# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into a short visual explanation on your own computer. it uses the current chat, so you do not need to explain the project again.

every lesson answers three questions: **why was this needed?**, **what did i build?**, and **how does it work?** the final part follows one real action from the command you run to the result you see. only the technologies needed to understand that path are included, each in one plain sentence.

## use it

finish building something, then run Teach in the same chat:

- **Codex:** type `$teach`, or open the `/` command picker and choose **Teach**.
- **Claude Code:** type `/teach`.

that is the whole prompt. if you want to steer the lesson, use the complete version for your agent:

```text
Codex:
$teach Explain why I needed this, what I built, and how it works from start to finish. Keep it short and use plain language.

Claude Code:
/teach Explain why I needed this, what I built, and how it works from start to finish. Keep it short and use plain language.
```

teach creates a standalone `index.html` under `~/teach-lessons/` and opens it on a local-only address. there is no account, cloud upload, tracking, or model API inside the page.

## install for Codex

add the public marketplace, then install teach:

```sh
codex plugin marketplace add udayanwalvekar/teach
codex plugin add teach@teach
```

start a new thread after installation so Codex loads the skill into the command picker.

## install as a Claude Code skill

Teach requires Python 3.9 or newer to build and serve the local lesson.

on macOS, Linux, or WSL, paste one command:

```sh
curl -fsSL "https://github.com/udayanwalvekar/teach/releases/download/v0.2.1/install.sh?download=1" | sh
```

on Windows PowerShell, paste:

```powershell
irm "https://github.com/udayanwalvekar/teach/releases/download/v0.2.1/install.ps1?download=1" | iex
```

the installer copies Teach to `~/.claude/skills/teach/`, the personal skill location used by Claude Code. start or restart Claude Code, finish building in a chat, and type `/teach` in that same chat.

to update later, copy the current install command from this README and run it again. the installer moves the previous copy to a timestamped backup before replacing it.

developers can install from a cloned repository instead:

```sh
git clone --depth 1 https://github.com/udayanwalvekar/teach.git
./teach/install-claude.sh
```

on Windows PowerShell:

```powershell
git clone --depth 1 https://github.com/udayanwalvekar/teach.git
.\teach\install-claude.ps1
```

## teaching style

teach uses a quiet black-and-white paper style: clear system type, thin rules, familiar controls, and no decorative color competing with the lesson.

every explanation is written for a curious 18-year-old and should take about three minutes to understand. ordinary words come before technical terms. teach lessons do not include quizzes, playgrounds, scores, or glossary popovers.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both agents: as a Codex plugin and as a personal Claude Code skill. the lesson runtime is dependency-free Python plus a self-contained HTML shell.
