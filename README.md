# teach

you built it. now understand it.

teach turns the thing you just made in Codex or Claude Code into a private interactive explanation on your own computer. it uses the current chat, so you do not need to explain the project again.

it answers two questions first: **what did i build?** and **how does it work?** then it follows one real action through the moving parts with clean, minimal diagrams. it names the actual tech stack—interface, frontend, backend, database, function calls, APIs, state, and hosting when they exist—and explains the job each part performs. every technical word gets a Kindle-style dotted underline: hover, tap, or focus it for a plain-English definition and what it means in this particular build. the same definitions form a complete dictionary at the end.

when something still feels fuzzy, the page helps you copy a better follow-up question back into the same chat. a small quiz checks whether the system makes sense, not whether you memorized vocabulary.

## use it

finish building something, then run Teach in the same chat:

- **Codex:** type `$teach`, or open the `/` command picker and choose **Teach**.
- **Claude Code:** type `/teach`.

that is the whole prompt. if you want to steer the lesson, add a sentence after the command:

```text
Teach me what I built in this chat. Explain what it does, how it works end to end, and what every technical term means in this specific build. Use clean interactive diagrams and finish with a short scenario quiz.
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

clone the repository and run the Claude installer:

```sh
git clone --depth 1 https://github.com/udayanwalvekar/teach.git
./teach/install-claude.sh
```

the installer copies Teach to `~/.claude/skills/teach/`, the personal skill location used by Claude Code. start or restart Claude Code, finish building in a chat, and type `/teach` in that same chat.

to update an existing Claude installation, pull the latest repository and run:

```sh
git pull --ff-only
./install-claude.sh --force
```

the installer moves the previous copy to a timestamped backup before replacing it.

## teaching style

teach looks like a workshop notebook you can touch: warm graph paper, ink-black type, electric-blue wires, and small citron and coral signals.

every explanation starts with what the builder accomplished, then shows how the real system works from start to finish. ordinary words come before technical terms. honest analogies support the actual components, fields, events, and decisions instead of replacing them. the main visual makes the invisible flow clickable, and every piece of jargon remains one hover or tap away.

## what v1 does not do

v1 does not host lessons on GrowthX, save progress across devices, or answer questions inside the page. those need a real product backend and belong in a later version.

## package shape

this repository ships the same Teach skill for both agents: as a Codex plugin and as a personal Claude Code skill. the lesson runtime is dependency-free Python plus a self-contained HTML shell.
