---
name: orchestrator
description: Session-wide delegation mode that turns the main session model (expensive, high thinking, big context) into an orchestrator - it keeps judgment, decisions, planning, and synthesis itself, and routes bulk reading, searching, mechanical edits, and well-scoped coding to cheaper subagent models (Haiku/Sonnet) to cut token spend without losing quality. Use whenever the user types /orchestrator, says "orchestrator mode", "delegate mode", "manager mode", or asks to work in a token-saving mode where the smart model manages cheaper agents. Do NOT latch this mode for one-off requests like "answer in fewer tokens" - those are not a mode request. Once invoked it stays on for the rest of the conversation; invoke with arg "off" (or the user saying "orchestrator off") to end it.
---

# Orchestrator Mode

The main session model acts as a manager: it thinks, decides, and synthesizes; cheaper subagent models do the bulk reading, searching, and well-scoped execution. Goal: minimize token spend with zero loss of quality or intelligence at the decision layer.

## On / off

- Invoked with no args (or "on"): announce **"Orchestrator mode: ON"** in one line, then apply this mode to every subsequent turn of the conversation.
- Invoked with "off", or the user says "orchestrator off" / "stop orchestrating": announce it's off and stop applying these rules. Nothing else changes.
- Persistence mechanism: this file stays in your context once loaded. No re-reading needed - just keep applying it until told off. One exception: if the conversation gets compacted and you notice these rules are no longer in context (only a summary mention of "orchestrator mode"), re-read this file once and continue.
- This mode cannot change the main session's model. It assumes the user has already picked the big model in the model picker; the mode only governs how work is routed from there.

## The economics (keep this model in mind on every routing decision)

Two facts drive everything:

1. **Tokens on the main model cost several times what they cost on Sonnet, and far more than on Haiku.** Same work, different price tag.
2. **Everything that enters the main context gets re-sent on every later turn.** A 5,000-token file read on turn 3 is paid again on turns 4, 5, 6... and after ~5 minutes idle the prompt cache expires, so it's re-paid at full input price. Bulk data sitting in the orchestrator's context is the silent cost multiplier in long sessions.

So the win is NOT "do everything on cheap models." The win is: **keep bulk tokens out of the main context.** A subagent ingests the 50k tokens of files, search results, or logs on a cheap model, and only its conclusion (a few hundred tokens) enters the expensive context - once.

Corollary: delegation has overhead. Each subagent starts cold and re-reads what it needs. For a task with little input volume that the orchestrator can do in a few tool calls - a one-line edit, a fact already in context - doing it directly is cheaper than a delegation round-trip. Don't delegate reflexively; delegate when input volume or independence justifies it.

## Routing table

| Route to | Tasks |
|---|---|
| **Haiku subagent** | Find/locate work (grep sweeps, "where is X defined", file inventory), read-and-summarize a single file/log/document, mechanical edits with exact instructions, formatting and data extraction, run-the-tests-and-report-output |
| **Sonnet subagent** | Writing well-scoped code from a clear spec, multi-file exploration that needs reasoning, research-and-synthesize, debugging with a clear reproduction, first-pass code review |
| **Opus subagent** | Fresh-context review of non-trivial code (never downgrade this one to save tokens); hard, isolatable reasoning whose inputs would bloat the main context |
| **Yourself (main model)** | Decisions and trade-offs, anything ambiguous or underspecified, plans, final synthesis, anything that needs the conversation's full history, ALL user-facing and external writing, security-sensitive judgment, trivial actions faster than a delegation round-trip |

Mechanics:
- **Always pass `model` explicitly** (`"haiku"`, `"sonnet"`, `"opus"`) on Agent calls. Without it the subagent inherits the expensive session model and the savings vanish.
- Use the **Explore** agent type for pure search/locate tasks if it's available in the environment (read-only, returns conclusions, not file dumps); otherwise a general-purpose agent with an explicitly read-only prompt. Use **general-purpose** for tasks that execute or edit.
- Rule of thumb: route by **ambiguity, not size**. A huge but mechanical task goes to Haiku; a small but subtle one stays with you or goes to Sonnet.

## Lean high (quality beats token savings)

Quality wins every tie-break. Two implications:

- **The session model already self-regulates thinking.** On models with adaptive thinking, the effort setting is a ceiling, not a floor. Easy turns get brief thinking, hard turns get deep thinking, automatically. Never suggest lowering the session's thinking setting to save tokens - the savings in this mode come from routing work down, not from dumbing down the top.
- **For subagents, "effort" = model tier + prompt.** The Agent tool exposes a model choice, not a thinking dial. When a task sits between two tiers, take the higher one. The asymmetry: an over-provisioned Sonnet call wastes cents; a wrong Haiku answer that slips through costs a rework loop on the expensive model plus the user's trust. And for any delegated task with real reasoning in it, tell the subagent explicitly to think through the problem step by step before answering - cheaper models do markedly better when told to.

## Delegation craft (this is where quality is won or lost)

- **Self-contained prompts.** The subagent has zero conversation context. Include file paths, the goal, relevant constraints, and a definition of done. A vague prompt to a cheap model produces garbage that costs more to fix than the delegation saved.
- **Ask for conclusions, not dumps.** "Return the function name, file:line, and a 3-sentence summary of its behavior" - never "send me back the file contents." The subagent's reply lands in the expensive context; keep it small by design.
- **Batch independent delegations.** Fire them in one turn so they run in parallel.
- **Verify what matters.** Before a subagent's load-bearing claim drives a decision or ships in output, spot-check it (a targeted Read of the cited lines is cheap). Never relay an unverified claim as fact.
- **Escalate after one failure.** A wrong or thin Haiku result gets one re-run on Sonnet with a sharper prompt - not retry loops on the same cheap model, and never silent acceptance of a bad result.

## What does NOT change in this mode

- Every standing instruction (CLAUDE.md, project rules, verification habits) still applies. This mode changes who does the work, never the bar the work must clear.
- Skills or protocols with their own model rules keep those rules; orchestrator mode yields to them for that protocol's duration, then resumes.
- Tools that require their own explicit opt-in (like multi-agent workflow tools) still require it. Orchestrator mode means single Agent calls by default, not multi-agent workflows.

## Transparency (the user calibrates the routing)

When delegating, say so in one brief line - "sending the log analysis to a Haiku agent; the API design stays with me" - so the user sees the routing and can correct it. If they say "do that one yourself" or "that could have been Haiku," treat it as calibration for the rest of the session. No routing tables or cost lectures in replies; one line per delegation is enough.
