# Claude Orchestrator Skill

A toggleable mode for Claude Code. Turn it on and the expensive model you're chatting with stops doing grunt work. It acts as a manager: it keeps the thinking (decisions, plans, synthesis, anything you'll read) and delegates the bulk work (file reading, searches, mechanical edits, well-scoped coding) to cheaper models like Haiku and Sonnet running as subagents.

The goal is to cut token spend without losing intelligence where it matters.

## Why this works

Two facts about how LLM conversations are billed:

1. Top-tier models cost several times more per token than Haiku.
2. Everything the main model reads lands in its context and gets re-sent on every later turn. A 5,000 token file read on turn 3 is paid for again on turns 4, 5, 6 and so on.

So the real win is keeping bulk tokens out of the expensive context. A subagent can ingest 50k tokens of files on a cheap model and hand back a 300 token conclusion. You pay for the bulk once, at the cheap rate.

The skill also knows when NOT to delegate. Tiny tasks are cheaper done directly, and quality-critical work never gets routed down a tier to save money.

## Install

```bash
git clone https://github.com/amart-builder/claude-orchestrator-skill.git
cp -r claude-orchestrator-skill/orchestrator ~/.claude/skills/
```

Start a new Claude Code session and `/orchestrator` is available in every project.

## Use

- Type `/orchestrator` to turn it on. It stays on for the rest of that conversation.
- Type `/orchestrator off` (or just say "orchestrator off") to end it.
- Claude announces each delegation in one line ("sending the log analysis to a Haiku agent") so you can see the routing and correct it.

It pays off most on long sessions with heavy reading: research, multi-file coding, "go through all of these files" tasks. Skip it for quick questions, since there's nothing to delegate.

## How it routes

| Goes to | Work |
|---|---|
| Haiku | Searches, "where is X defined", reading and summarizing single files or logs, mechanical edits, running tests and reporting output |
| Sonnet | Well-scoped coding from a clear spec, multi-file exploration, research and synthesis, debugging with a clear repro |
| Opus | Fresh-context code review, hard isolated reasoning with bulky inputs |
| Main model | Decisions, anything ambiguous, plans, final synthesis, all user-facing writing, anything needing the full conversation history |

The rule of thumb inside the skill: route by ambiguity, not size. A huge mechanical task goes to Haiku. A small subtle one stays at the top.

## Requirements

Claude Code with subagent support (the Agent tool with per-agent model overrides). No other dependencies.

## License

MIT
