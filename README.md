# Claude Orchestrator Skill

A toggleable mode for Claude Code. Turn it on and the expensive model you're chatting with stops doing grunt work. It acts as a team leader: it keeps the thinking (decisions, plans, synthesis, anything you'll read) and delegates the bulk work (file reading, searches, mechanical edits, well-scoped coding) to cheaper models like Haiku and Sonnet running as subagents.

The goal is the best work the team can produce, at the lowest spend that doesn't compromise it.

New in this version: a peer-consultant lane (GPT-5.6 Sol through the Codex CLI, if you have it), a leadership playbook for getting and settling second opinions, routing guidance for non-coding work, and an optional hook that enforces the delegation budget instead of just asking nicely.

## Why this works

The dominant cost in a long session is not the size of any one file. It's the number of times the expensive model reaches for a tool. Every tool call re-sends the entire conversation to the top-tier model before it does anything. Twelve tool calls on a 150k-token context is roughly 1.8M tokens of re-reads in a single turn. Prompt caching softens that, but a tenth of a huge number on the priciest model is still the biggest line on the bill.

So there are two levers, in order of impact:

1. **Fewer round-trips on the expensive model.** A 15-step investigation done directly is 15 expensive re-sends of the whole context. Bundled into one subagent, it's 15 cheap re-sends on a small fresh context plus 2 expensive ones (dispatch and result).
2. **A smaller main context.** Bulk data that lands in the main context is re-paid on every later turn. A subagent ingests 50k tokens on a cheap model and hands back a 300-token conclusion.

The core rule that makes this stick is a routing budget: before acting, the model estimates how many tool calls a task needs. Three or fewer, it does the work directly (delegation would cost more than it saves). More than three, it declares a delegation plan up front and routes the bulk work down. This was added after an early version, running as advisory prose, delegated once across 28 prompts and 354 tool calls. Good intentions weren't enough; a hard budget is.

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
| Codex CLI running GPT-5.6 Sol (optional) | Peer consults on creative and strategic decisions, a cross-model second review on top of the Opus one, terminal-heavy autonomous jobs, overflow when Claude limits are tight |
| Grok CLI (optional) | Live web/X data reads, a cheap third opinion in idea panels, experimental cheap-bulk coding (not load-bearing) |
| Main model | Decisions, anything ambiguous, plans, final synthesis, all user-facing writing, anything needing the full conversation history |

The rule of thumb inside the skill: route by ambiguity, not size. A huge mechanical task goes to Haiku. A small subtle one stays at the top.

## Second opinions, built in

Cost routing is only half the skill. The other half makes the model act like a leader instead of a dispatcher:

- On creative, architectural, or strategic decisions, it consults GPT-5.6 Sol (read-only, through the Codex CLI) by default and synthesizes both views before committing. Different model family, different blind spots.
- On genuinely open problems, it can fan out 2 or 3 subagents with different framings (builder, skeptic, user-advocate) and settle disagreements with evidence, not confidence. A disagreement the evidence can't settle goes to you as a named decision.
- On hard-to-reverse or client-facing calls, it deliberately slows down and spends tokens on critique instead of racing to an answer.

The SKILL.md carries calibrated trust rules for the external lanes, including why Sol's executed work always gets independently re-verified (its reward-hacking record is real) while its read-only opinions run freely.

If you also run vendor CLIs (OpenAI's Codex, xAI's Grok), the skill dispatches to them as extra lanes via Bash. They're optional; the skill works fully without them. See the "External lanes" section in `orchestrator/SKILL.md` for the dispatch shapes and safety rules.

## Optional: the enforcement hook

A skill file can instruct, but it can't enforce. Real-session data showed the mode fading in long sessions: the model slides back into doing everything itself. The fix is a tiny hook that counts direct tool calls per turn and injects a one-line nudge into the model's context after 5 calls with no delegation (then every 5 after). It never blocks anything, and it exits silently on any error.

Install (requires python3):

```bash
cp claude-orchestrator-skill/hooks/orchestrator-budget.py ~/.claude/hooks/
```

Then add to the `"hooks"` section of `~/.claude/settings.json` (merge with what's there):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/orchestrator-budget.py", "timeout": 5 }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "python3 ~/.claude/hooks/orchestrator-budget.py", "timeout": 5 }]
      }
    ]
  }
}
```

Trade-off to know: the hook spawns a python process after every tool call, roughly 50 to 100ms each. It also nudges in every session, not just orchestrator ones, on the theory that gentle delegation pressure is rarely wrong. Delete the two settings entries to turn it off.

## Requirements

Claude Code with subagent support (the Agent tool with per-agent model overrides). No other dependencies. The optional external lanes need the respective vendor CLI installed and authenticated (OpenAI Codex CLI with a ChatGPT subscription or API key, xAI Grok CLI); without them the skill just uses the Claude tiers. The optional enforcement hook needs python3.

## License

MIT
