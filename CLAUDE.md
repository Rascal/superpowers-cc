# Superpowers CC — Maintainer Notes

A personal, Claude-Code-only fork of [obra/superpowers](https://github.com/obra/superpowers). These notes govern how to change this plugin safely. They are about maintaining *this* repo, not about contributing upstream.

## Skills are behavior-shaping code, not prose

The skill files do not just document a workflow — they steer agent behavior under load. Treat edits to them like code changes:

- Develop and test skill changes with `superpowers-cc:writing-skills`.
- Pressure-test across multiple fresh sessions before trusting a change — a skill that reads well can still fail to trigger or get rationalized away in practice.
- Do **not** casually reword carefully-tuned content (Red Flags tables, rationalization lists, the `<EXTREMELY-IMPORTANT>` bootstrap, "your human partner" phrasing) without evidence the change is an improvement. "Looks redundant" is how auto-triggering quietly breaks.
- `using-superpowers` is the load-bearing bootstrap injected every session by the `session-start` hook. It is what makes skills auto-trigger. Be especially conservative editing it.

The term **"your human partner"** is deliberate and not interchangeable with "the user."

## Understand before you change

Before reworking skill design, workflow philosophy, or architecture, read the existing skills and understand why they are shaped the way they are. This fork inherits a tested philosophy about skill design and agent behavior; rewrites that ignore it tend to regress.

## Scope

- **Claude Code only, Opus/Fable-class models.** This plugin targets the Claude Code harness exclusively and is tuned for Opus/Fable-class models. The upstream cross-harness support was dropped on purpose — don't add support for other harnesses or CLIs.
- **Never hardcode a model in skill text.** Don't name a specific model in skill instructions or examples. Skills defer model selection to the user's chosen model — the session model, or whatever a CLAUDE.md rule pins for subagents (this workflow pins Opus). Naming a model in operational guidance is drift waiting to happen; let the user's config decide. "Tuned for Opus/Fable-class" describes the tested target, not a value to bake into dispatches. The `subagent-driven-development` "Model Selection" section is the canonical pattern — inherit the session model, defer to CLAUDE.md.
- **Zero runtime dependencies.** Skills and hooks rely only on the harness and standard shell tools. If a change needs an external tool or service, it belongs in its own plugin, not here.
- **General-purpose skills.** Keep skills useful across different kinds of projects. Domain-, tool-, or workflow-specific helpers belong in a separate plugin.

## General

- One concern per change — don't bundle unrelated edits.
- Describe the problem a change solves, not just what it changed.
- Keep `plugin.json` / `marketplace.json` / `package.json` versions in sync when bumping.
- When the Claude Code harness changes, or before shipping skill/hook edits, run `bash scripts/check-tool-drift.sh` (then have Claude diff sections 2-5 against the live session's tools) to catch drift — renamed tools, invalid task statuses, dropped agent types — before it rots silently in skill and hook text.
