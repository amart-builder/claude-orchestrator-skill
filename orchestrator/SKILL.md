---
name: orchestrator
description: Session-wide delegation mode that turns the main session model (expensive, high thinking, big context) into an orchestrator - it keeps judgment, decisions, planning, and synthesis itself, and routes bulk reading, searching, mechanical edits, and well-scoped coding to cheaper subagent models (Haiku/Sonnet/Opus), tiered and effort-tuned to each task, to cut token spend without losing quality. Use whenever the user types /orchestrator, says "orchestrator mode", "delegate mode", "manager mode", or asks to work in a token-saving mode where the smart model manages cheaper agents. Do NOT latch this mode for one-off requests like "answer in fewer tokens" - those are not a mode request. Once invoked it stays on for the rest of the conversation; invoke with arg "off" (or the user saying "orchestrator off") to end it.
---

# Orchestrator Mode

The main session model acts as a manager: it thinks, decides, and synthesizes; subagents do the tool-heavy work. Goal: cut token spend with zero loss of quality at the decision layer.

## On / off

- Invoked with no args (or "on"): announce **"Orchestrator mode: ON"** in one line, then apply this mode to every subsequent turn.
- Invoked with "off", or the user says "orchestrator off" / "stop orchestrating": announce it's off and stop. Nothing else changes.
- Persistence: this file stays in context once loaded. If the conversation gets compacted and these rules are no longer in context (only a summary mention of "orchestrator mode"), re-read this file once and continue.
- This mode cannot change the main session's model; it assumes the user has already picked the big model in the model picker. It only governs how work is routed from there.

## The real cost model (this is the whole game)

**Every tool call the main model makes re-sends the entire conversation.** One turn with 12 tool calls on a 150k-token context ≈ 1.8M tokens of context re-reads on the expensive model — before any output. Prompt caching softens this (cached re-reads bill at roughly a tenth of fresh input, and count less against plan limits too) — but a tenth of an enormous number on the priciest model is still the biggest line item, and the cache expires after ~5 idle minutes, after which the whole context re-bills at full price once. Cost of a turn ≈ (number of main-model API round-trips) × (context size), plus output.

This mode was rebuilt after a real session with the mode ON ran 28 prompts, made 354 main-model calls, and delegated exactly **once** — 59.5M tokens of context re-reads vs 1.5M of output. The failure mode is always under-delegation, not over-delegation. Advisory prose about "keeping bulk tokens out of context" was not enough; a hard routing budget (below) is.

So there are two levers, in order of impact:

1. **Fewer main-model round-trips.** A 15-step investigation done directly = 15 expensive re-sends. The same work bundled into one subagent = 15 cheap re-sends on a small fresh context + 2 expensive ones (dispatch + result). This is where the savings live.
2. **Smaller main context.** Bulk data (file contents, logs, search dumps) that enters the main context is re-paid on *every* later round-trip for the rest of the session. A subagent ingests the 50k tokens and returns a few hundred.

Corollary: delegation itself costs a round-trip. A task the main model can finish in 1-3 tool calls is cheaper done directly. The unit of delegation is a **goal, not a step** — never spawn a subagent for one grep.

## The binding rule: the 3-call budget

At the start of each turn, estimate the tool calls the task needs. This is a routing decision, made before the first tool call, every turn:

- **≤ 3 tool calls** → do it directly. Delegating would cost more than it saves.
- **> 3 tool calls** → carve the work into delegated goals, and **declare the routing in your first line, before any tool call**: "This looks like ~10 calls — delegating the search to Haiku and the fix to Sonnet; I'll verify and synthesize." Naming the subagents up front, while the routing decision is still cheap to act on, is the enforcement mechanism — a retrospective tally at the end of a turn can only report a breach, not prevent one. Direct calls in a delegating turn are reserved for: dispatching agents, spot-check verification of subagent claims, and actions that genuinely need the conversation's full history.
- Multi-step work whose *shape* is unknown ("audit X", "find why Y is slow", "clean up Z") is the classic trap — it feels like "just one quick look" and becomes 20 round-trips. Unknown shape = delegate the investigation itself, with a clear definition of done.
- If a turn blows past the budget anyway (it happens — a direct task grows), stop at the breach, bundle the remainder into a subagent, and note the miss in one line. Do not ride it out directly.

This rule is the mode. Everything else is tuning. Be honest about its limits: a skill file can instruct, not enforce — if the user notices the mode fading in long sessions anyway, the durable fix is a harness-level hook, and they should build one.

## Routing table

Model names below use the generic tiers the Agent tool accepts (`"haiku"`, `"sonnet"`, `"opus"`); each resolves to your harness's current version of that tier, cheap→capable.

| Route to | Tasks |
|---|---|
| **Haiku** (`model: "haiku"`) | Find/locate sweeps, read-and-summarize a file/log/document, mechanical edits with exact instructions, formatting and extraction, run-tests-and-report |
| **Sonnet** (`model: "sonnet"`) | Well-scoped coding from a clear spec, multi-file exploration needing reasoning, research-and-synthesize, debugging with a clear repro, first-pass review, bundled investigations of unknown shape |
| **Opus** (`model: "opus"`) | Fresh-context review of non-trivial code (never downgrade this one to save tokens), hard isolatable reasoning, tricky multi-file changes beyond Sonnet |
| **Yourself (main model)** | Decisions and trade-offs, anything ambiguous, plans, final synthesis, anything needing full conversation history, ALL user-facing and external writing, security-sensitive judgment, ≤3-call tasks |

If the session model itself is the top tier, delegating to a peer tier saves nothing on per-token price — the only win there is context isolation (bulk stays out of the main context). Delegating *below* the session model wins on both price and isolation.

Mechanics:

- **Always pass `model` explicitly** on Agent calls. Without it the subagent inherits the expensive session model and the savings vanish. This is the single most common silent failure — check it on every dispatch.
- Route by **ambiguity, not size**: huge-but-mechanical → Haiku; small-but-subtle → Sonnet or keep it. When a task sits between tiers, take the higher one — an over-provisioned call wastes cents; a wrong cheap answer costs an expensive rework loop.
- Use the **Explore** agent type for pure search/locate if available (read-only, returns conclusions); **general-purpose** for tasks that execute or edit.
- **Batch independent delegations in one message** so they run in parallel — each separately-awaited dispatch is its own expensive round-trip.
- To continue a subagent that already has the context loaded, send it a follow-up message instead of spawning a fresh one that re-reads everything.

## Delegation craft (where quality is won or lost)

- **Self-contained prompts.** The subagent has zero conversation context. Include file paths, the goal, constraints, and a definition of done. A vague prompt to a cheap model produces garbage that costs more than the delegation saved.
- **Ask for conclusions, not dumps.** "Return file:line and a 3-sentence summary" — never "send me the file contents." The reply lands in the expensive context permanently.
- **Subagents return findings and raw notes, never finished prose.** Anything a human will read — replies, emails, docs, posts — is written by the main model, in the user's voice, from the subagent's findings. A "research-and-synthesize" delegation returns structured findings; the final write-up stays with the main model.
- **Demand reasoning from mid-tier models.** Haiku gets "do exactly this, don't overthink"; Sonnet/Opus on subtle work gets "think it through step by step before answering" — cheaper models do markedly better when told to. If you escalate to a multi-agent workflow tool (which needs its own explicit opt-in), use its per-stage effort option the same way.
- **Verify what matters.** Before a subagent's load-bearing claim drives a decision or ships, spot-check it (a targeted read of cited lines — this is a sanctioned direct call). Never relay an unverified claim as fact.
- **Escalate after one failure.** A wrong or thin Haiku result gets one re-run on Sonnet with a sharper prompt — not retry loops on the same tier, never silent acceptance.

## What does NOT change

- Every standing instruction (CLAUDE.md, project rules, verification habits) still applies. This mode changes who does the work, never the bar the work must clear.
- The session model self-regulates thinking — never lower its thinking setting to save tokens. Savings come from routing work down, not dumbing down the top.
- Skills or protocols with their own model rules keep those rules; this mode yields for that protocol's duration, then resumes.

## Transparency and self-audit (keeps the mode honest)

- The pre-turn routing declaration (above) doubles as the transparency line — the user sees the routing and can correct it ("do that one yourself" / "that could have been Haiku"). Treat corrections as calibration for the rest of the session. No other per-turn accounting: no tallies, no cost lectures.
- Note a budget miss in one line only when it actually happens (more than 3 direct calls with no delegation). Surface the misses, not routine bookkeeping.
- Honest accounting: delegation usually *raises* total tokens across all models while cutting expensive-model spend. If the user asks whether it's working, the metric is main-model round-trips per prompt and main-context size — not the session's total token counter, which counts subagent work too.

## What this mode cannot fix (say so instead of pretending)

Per-turn baseline cost — system prompt, standing instruction files, MCP tool schemas — is paid on every round-trip regardless of routing. If sessions feel expensive while idle-ish, the fix is disabling unused MCP servers and trimming instruction files, not more delegation. Single-prompt quick tasks won't show savings at all; this mode earns its keep in long working sessions.
