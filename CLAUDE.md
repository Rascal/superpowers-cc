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

- **Claude Code only.** This fork drops the upstream cross-harness support (Codex/Cursor/Gemini/OpenCode/Copilot) on purpose. Don't reintroduce it.
- **Zero runtime dependencies.** Skills and hooks rely only on the harness and standard shell tools. If a change needs an external tool or service, it belongs in its own plugin, not here.
- **General-purpose skills.** Keep skills useful across different kinds of projects. Domain-, tool-, or workflow-specific helpers belong in a separate plugin.

## General

- One concern per change — don't bundle unrelated edits.
- Describe the problem a change solves, not just what it changed.
- Keep `plugin.json` / `marketplace.json` / `package.json` versions in sync when bumping.
