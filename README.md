# Multi-Model Orchestrator Skills

Two native skills that make a frontier model the CEO of a cross-vendor agent team. Same doctrine in both; the seats are chosen by whichever model is driving.

| Driving the session | Writes the code | Plan advisor | Reviewer (fresh context, adversarial) | Skill |
|---|---|---|---|---|
| **Claude Fable 5** | GPT-5.6 Sol, DO mode, high effort | the driver | Claude Opus 5, read-only | `orchestrator` for Claude Code |
| **Claude Opus 5** | the driver | GPT-5.6 Sol, read-only | GPT-5.6 Sol, read-only | `orchestrator` for Claude Code |
| **GPT-5.6 Sol** | the driver | Claude Opus 5, read-only | Claude Opus 5, read-only | `codex-orchestrator` for Codex and ChatGPT desktop |

Two invariants hold across every row:

- **Whoever built it never certifies it, and the reviewer always comes from a different family than the builder.** This is the whole point. Two runs of the same model make correlated mistakes, because the same training produces the same blind spots, so a second pass mostly agrees with the first. A model from a different lab fails in different places. The corollary lives in both skills: agreement between the two is weaker evidence than it feels, and disagreement is a signal to slow down rather than to average.
- **The driver makes every final call.** Advisers and reviewers produce evidence and disagreement. They never hold the decision, and a review is never a rubber stamp or a veto.

Both share one North Star with two goals in order: maximize the driver's performance on multi-disciplinary work, and minimize the tokens spent getting it. Quality wins when the two genuinely collide, but the bet is that they rarely do. To that end the skill grants the driver two things it does not otherwise use freely: a frontier peer from another model family to think alongside it and to check its work, and a roster of cheaper but still capable workers to hand bounded work to whenever that saves tokens without costing quality. A short precedence list at the top of each skill settles rule conflicts, in order: user authorization and safety first, judgment and authorship stay with the driver, consult the cross-family peer when an independent frame could change the answer, delegate bounded work, keep the fresh-context review independent of whoever executed, and only then minimize cost.

## How it routes

- **The call budget.** Before each turn the driver estimates the tool calls needed. Three or fewer, it works directly. More, it declares a routing plan in its first line and hands the bulk to workers. Creative and strategic turns still get a peer consult even when small, and neither acceptance verification nor the review gate ever counts against the budget. When Opus 5 drives, the budget becomes a coordination-cost rule rather than a cost rule: a handoff has to earn itself on quality, not on savings.
- **Two spawn modes, chosen per task.** DO mode gives a worker full tools to actually change things, under a spec contract whose acceptance check is written before implementation and held out of the worker's spec. ADVISE mode is for second opinions and review: no edits, no changes, but never toolless. An adviser keeps read access so its opinion is grounded in the actual code, and review is always ADVISE because a reviewer should not be able to modify the thing it reviews.
- **The peer relationship, in two stages.** Plan advice and end review are not duplicates and cannot substitute for each other. The advisor helps the driver choose the path before or during the work, using a structured brief and a structured response contract (disagreements, assumptions, evidence with references, recommended change, confidence). The reviewer challenges the finished result afterward in fresh context, returning `PASS`, `CHANGES_REQUIRED`, or `BLOCKED` with findings ordered by severity. A `PASS` without concrete review evidence is thin, not clearance.

The driver always keeps ambiguity resolution, synthesis across workstreams, go or no-go decisions, security-sensitive judgment, and final user-facing prose.

One rule is worth lifting out, because it applies to any harness where the driver both builds and verifies: **the implementer does not certify completion.** An agent that chose the implementation, knows the acceptance check, and interprets its own ambiguous output is not verifying independently, no matter how fresh the command is. Acceptance criteria get written before implementation, and the check runs in a context that did not build the thing.

## Why two skills

Claude Code and Codex expose different subagent, model-selection, hook, and installation mechanics. One branching skill would be harder to reason about and easier to misconfigure. Two native skills let each lead use its own runtime well while keeping the leadership contract consistent.

Within the Claude skill, the two driver rows are not a mode you pick. The skill reads which model is running the session and takes the matching row, because that is the only thing the seat map actually depends on.

## Install the Claude-native skill

```bash
git clone https://github.com/amart-builder/claude-orchestrator-skill.git
mkdir -p ~/.claude/skills
cp -R claude-orchestrator-skill/orchestrator ~/.claude/skills/
```

Start a new Claude Code session on Fable 5 or Opus 5 and run:

```text
/orchestrator
```

The skill detects the session model and takes that row. `/orchestrator fable` and `/orchestrator opus` force a row if you want to override the detection. `/orchestrator president` keeps the same seats with minimal ceremony: no per-turn routing declarations and no default peer consults, though high-stakes calls still get them, and the build seat and verification rules are unchanged. `orchestrator off` ends the mode.

The skill cannot switch the active session model. If neither Fable 5 nor Opus 5 is active, it reports the mismatch and continues safely on the selected model until you switch.

### The Opus 5 row

When Opus 5 is driving, the North Star's token-minimizing goal is suspended entirely: that row is for operators who are not token-constrained and want the best answer available rather than the cheapest. Opus writes the code itself, and GPT-5.6 Sol becomes an ADVISE-only peer that never touches a file, used through three read-only plays. **Diverge** hands it the problem cold with your leaning withheld, before you commit to an approach. **Red-team** asks it to break a plan you already have. **Cross-review** puts the finished artifact in front of it. Effort defaults to `xhigh` here rather than `high`.

That row also carries prompting rules specific to Opus 5, which behaves differently enough from earlier Opus models to need them: it self-verifies unprompted (so generic "double-check your work" instructions are banned as wasteful, while task-specific checks are kept as specification content), it delegates more readily than prior models (so the row caps spawning on coordination grounds), and it runs longer by default in both conversation and written files (so length is prompted for explicitly).

## Install the Codex-native skill

```bash
git clone https://github.com/amart-builder/claude-orchestrator-skill.git
mkdir -p ~/.agents/skills
cp -R claude-orchestrator-skill/codex-orchestrator ~/.agents/skills/orchestrator
```

Start a new Codex task and invoke:

```text
$orchestrator
```

You can also say `orchestrator mode` or `manager mode`. GPT-5.6 Sol is the intended lead, and it holds the build seat: it writes its own code rather than routing implementation to a worker. Claude Opus 5 fills both peer seats through two helper scripts, `scripts/opus-consult.sh` for plan advice and `scripts/opus-review.sh` for the fresh-context review. Both enforce read-only plan mode with no session persistence, so the peer cannot edit the work it is judging. The `claude` CLI must be installed and authenticated for those lanes. If the peer lane is unavailable, the skill labels substantive work `NOT REVIEWED` rather than representing it as checked.

`scripts/fable-consult.sh` ships alongside them as an optional third voice for genuine panels. It is not part of the seat map.

The skill reports a model mismatch instead of pretending it changed the active model.

OpenAI documents local skills for the ChatGPT desktop app, Codex CLI, and the IDE extension. Ordinary ChatGPT web chat does not install a local skill folder. ChatGPT Work on the web uses the separate plugin distribution path. See [Build skills](https://learn.chatgpt.com/docs/build-skills).

## Model rosters

The tables are routing candidates, not permanent truth. Each skill verifies model and tool availability in the active runtime before relying on a lane.

### Claude-native roster

| Candidate | Best-fit work |
|---|---|
| Fable 5 lead | Ambiguity, strategy, creative direction, cross-domain synthesis, high-stakes decisions, final prose |
| Haiku | Locate and extract, mechanical edits, formatting, test execution, simple summaries |
| Sonnet | Research synthesis, multi-file exploration, debugging with a clear reproduction; coding only when it's very simple and certain to land |
| Opus 5 | The reviewer seat when Fable drives: fresh-context adversarial review of every substantive result. Hard isolated reasoning. Backup coding implementer at max effort when Sol is unavailable. Drives and holds the build seat when it is the session model |
| GPT-5.6 Sol | Coding implementer when Fable drives (high effort, spec in, held-out verification). Plan advisor and reviewer when Opus drives. Frontier cross-model critique either way |
| GPT-5.6 Terra | Balanced everyday agentic work through the Codex CLI |
| GPT-5.6 Luna | Fast and affordable bounded work through the Codex CLI |
| Grok | Live X research and an optional third perspective |

### Codex-native roster

| Candidate | Best-fit work |
|---|---|
| GPT-5.6 Sol lead | Ambiguity, strategy, architecture, synthesis, high-stakes decisions, final prose, and its own coding implementation |
| Claude Opus 5 | Both peer seats: read-only plan advisor before the work, mandatory fresh-context reviewer after it |
| GPT-5.6 Terra | Bounded work around the lead's build: investigation, structured research, fully specified mechanical implementation, a second review lane |
| GPT-5.6 Luna | Fast and affordable searches, extraction, mechanical changes, and test runs |
| Native Codex subagent | Parallel exploration, context isolation, independent review |
| Claude Sonnet or Haiku | Optional cross-model lanes when the Codex lanes are saturated |
| Fable 5 | Optional third voice in a genuine panel; not part of the seat map |
| Grok | Live X research and an optional third perspective |

## Use and transparency

- Turn the active skill on with `/orchestrator` in Claude Code or `$orchestrator` in Codex.
- Say `orchestrator off` to end the mode.
- The lead announces its seats on invocation and announces substantive routing in one short line, so you can correct it.
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

- Claude skill: Claude Code with subagent support, running Fable 5 or Opus 5. The Codex CLI is required for the Sol lane in both rows, as builder under Fable and as peer under Opus. The Grok CLI is optional.
- Codex skill: Codex with multi-agent support. The `claude` CLI is required for the Opus peer seats, which include the mandatory review gate.
- External lanes must be installed, authenticated, and smoke-tested before use.
- Model-specific execution must fall back cleanly when a named model is unavailable.

## License

MIT
