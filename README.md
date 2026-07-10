# Multi-Model Orchestrator Skills

Two native skills that turn a frontier model into a quality-first team leader.

| Skill | Intended lead | Independent peer |
|---|---|---|
| `orchestrator` for Claude Code | Fable 5 | GPT-5.6 Sol |
| `codex-orchestrator` for Codex and ChatGPT desktop | GPT-5.6 Sol | Fable 5 |

Both skills follow the same principle: the lead keeps the work where its judgment, creativity, context, or voice matters, and delegates bounded work only when another model can preserve the quality bar. The lead also chooses the worker model by task fit, expected quality, cost, latency, context isolation, and tools. Price alone never decides the route.

## The delegation gate

A task is delegable only when all five conditions hold:

1. **Bounded:** the lead can specify the objective, inputs, constraints, and definition of done without leaving hidden judgment calls.
2. **Verifiable:** the lead can check the result cheaply and concretely without redoing the task.
3. **Model-fit:** a verified worker is expected to match or beat the required quality for that task type.
4. **Worth the round trip:** dispatch, review, and likely retry cost less than direct execution.
5. **Context-safe:** the worker does not need the full conversation to get the task right.

The lead always keeps ambiguity resolution, synthesis across workstreams, go or no-go decisions, security-sensitive judgment, and final user-facing prose.

## Why two skills

Claude Code and Codex expose different subagent, model-selection, hook, and installation mechanics. One branching skill would be harder to reason about and easier to misconfigure. Two native skills let each lead use its own runtime well while keeping the leadership contract consistent.

The peer relationship is symmetric but not automatic. Consult the peer when:

- the lead is genuinely uncertain;
- the decision is hard to reverse or high stakes;
- the peer has a known advantage or different blind spot;
- a cross-model review is worth the added latency and cost.

The lead treats the peer as an independent senior opinion, not a rubber stamp or a subordinate. It still verifies claims, resolves disagreements with evidence, and owns the final decision.

## Install the Claude-native skill

```bash
git clone https://github.com/amart-builder/claude-orchestrator-skill.git
mkdir -p ~/.claude/skills
cp -R claude-orchestrator-skill/orchestrator ~/.claude/skills/
```

Start a new Claude Code session, select Fable 5, and run:

```text
/orchestrator
```

The skill cannot switch the active session model. If Fable 5 is not active, it reports the mismatch and continues safely on the selected model until you switch.

## Install the Codex-native skill

```bash
git clone https://github.com/amart-builder/claude-orchestrator-skill.git
mkdir -p ~/.agents/skills
cp -R claude-orchestrator-skill/codex-orchestrator ~/.agents/skills/
```

Start a new Codex task and invoke:

```text
$codex-orchestrator
```

You can also say `orchestrator mode` or `manager mode`. GPT-5.6 Sol is the intended lead. The skill reports a model mismatch instead of pretending it changed the active model.

OpenAI documents local skills for the ChatGPT desktop app, Codex CLI, and the IDE extension. Ordinary ChatGPT web chat does not install a local skill folder. ChatGPT Work on the web uses the separate plugin distribution path. See [Build skills](https://learn.chatgpt.com/docs/build-skills).

## Model rosters

The tables are routing candidates, not permanent truth. Each skill verifies model and tool availability in the active runtime before relying on a lane.

### Claude-native roster

| Candidate | Best-fit work |
|---|---|
| Fable 5 lead | Ambiguity, strategy, creative direction, cross-domain synthesis, high-stakes decisions, final prose |
| Haiku | Locate and extract, mechanical edits, formatting, test execution, simple summaries |
| Sonnet | Well-scoped coding, research synthesis, debugging with a clear reproduction, multi-file exploration |
| Opus | Fresh-context review, hard isolated reasoning, tricky implementation |
| GPT-5.6 Sol | Independent peer critique, terminal-heavy work, frontier cross-model review |
| GPT-5.6 Terra | Balanced everyday agentic work through the Codex CLI |
| GPT-5.6 Luna | Fast and affordable bounded work through the Codex CLI |
| Grok | Live X research and an optional third perspective |

### Codex-native roster

| Candidate | Best-fit work |
|---|---|
| GPT-5.6 Sol lead | Ambiguity, strategy, architecture, synthesis, high-stakes decisions, final prose |
| GPT-5.6 Terra | Balanced everyday implementation, investigation, and structured research |
| GPT-5.6 Luna | Fast and affordable searches, extraction, mechanical changes, and test runs |
| Native Codex subagent | Parallel exploration, context isolation, scoped implementation, independent review |
| Fable 5 | Independent creative, strategic, architectural, or high-stakes peer critique |
| Claude Sonnet or Opus | Optional cross-model implementation or review specialist when locally available |
| Grok | Live X research and an optional third perspective |

## Use and transparency

- Turn the active skill on with `/orchestrator` in Claude Code or `$codex-orchestrator` in Codex.
- Say `orchestrator off` to end the mode.
- The lead announces substantive routing in one short line so you can correct it.
- Small tasks stay direct. Multi-step or unknown-shape work triggers a delegation assessment, not automatic delegation.
- The lead re-runs load-bearing verification and never relays a worker's confidence as evidence.

## Optional Claude enforcement hook

The repository includes `hooks/orchestrator-budget.py`, a Claude Code hook that nudges the lead after five direct tool calls without delegation. It is advisory and never blocks.

```bash
cp claude-orchestrator-skill/hooks/orchestrator-budget.py ~/.claude/hooks/
```

Merge these entries into `~/.claude/settings.json`:

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

This hook is Claude-specific. Do not install it as a Codex hook. The Codex skill remains instruction-driven until a separately tested Codex-native hook exists.

## Requirements

- Claude skill: Claude Code with subagent support. Codex and Grok CLI lanes are optional.
- Codex skill: Codex with multi-agent support. The Claude CLI is optional and required only for the Fable peer lane.
- External lanes must be installed, authenticated, and smoke-tested before use.
- Model-specific execution must fall back cleanly when a named model is unavailable.

## License

MIT
