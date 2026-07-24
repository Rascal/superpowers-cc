#!/usr/bin/env bash
# check-tool-drift.sh — inventory drift-prone Claude Code harness references
# across the plugin, so renamed tools, changed enums, or dropped agent types are
# easy to spot instead of rotting silently in skill and hook text.
#
# It mostly EXTRACTS and GROUPS (a standalone script can't see the live harness).
# Run it while maintaining the plugin, then have Claude diff each extracted name
# against the tools actually available in the session (sections 2-5). The one
# baked-in judgment is the TaskUpdate status enum — small, stable, and the thing
# that has actually drifted (`status=cancelled`).
#
# Usage:  scripts/check-tool-drift.sh [-v|--verbose]
#   -v   also print file:line for every reference (default: counts only, plus
#        locations for any DRIFT-flagged status)
#
# Zero runtime dependencies: bash + GNU grep/sed/sort/awk (Git Bash OK on Windows).

set -eu

VERBOSE=0
case "${1:-}" in
  -v|--verbose) VERBOSE=1 ;;
  "") : ;;
  *) echo "usage: $0 [-v|--verbose]" >&2; exit 2 ;;
esac

# TaskUpdate status enum — the ONLY hardcoded valid-set. Update it here if the
# harness ever changes the enum (verify against the live TaskUpdate schema).
VALID_STATUSES="pending in_progress completed deleted"

# CamelCase tokens that look like tools but aren't. Keep this tiny: it only
# suppresses report noise, it is NOT a tool allowlist.
IGNORE_TOKENS="GitHub JavaScript TypeScript BigQuery WebSocket FormData PyPI PyMuPDF"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"

# Only scan targets that exist (a trimmed checkout must not error).
SCAN_PATHS=""
for p in skills hooks commands docs README.md CLAUDE.md; do
  if [ -e "$p" ]; then SCAN_PATHS="$SCAN_PATHS $p"; fi
done

# grep wrappers that never abort the script on zero matches, and never scan this
# tool's own files (they mention tool names by construction).
EXCL="--exclude=check-tool-drift.*"
g_oh() { grep -rEohI $EXCL "$1" $SCAN_PATHS 2>/dev/null || true; }  # matches only
g_n()  { grep -rEnI  $EXCL "$1" $SCAN_PATHS 2>/dev/null || true; }  # file:line:match

sep() { printf '\n%s\n' "------------------------------------------------------------"; }

# =, or :, optionally wrapped in quotes/space — matches subagent_type: x,
# matcher="x", etc.
ASSIGN='["'"'"']?[[:space:]]*[=:][[:space:]]*["'"'"']?'

# Task statuses are validated only in the tight `status=VALUE` form the plugin
# uses in prose/advice (`TaskUpdate status=deleted`). That is the form that has
# actually drifted, and it avoids code false-positives like Python `status =
# inp.get(...)` or a JS example's `status: 'success'` (spaced `=` / colon forms).
STATUS_RE='\bstatus=["'"'"']?[a-z_]+'

# CamelCase suffixes that are programming constructs, never Claude Code tools.
NOISE_SUFFIX='(Error|Exception|Manager|Handler|Factory|Reader|Writer|Iterator|Listener|Adapter|Wrapper|Builder|Provider|Controller|Repository)$'

printf 'Tool-drift inventory for: %s\n' "$ROOT"
printf 'Scanned:%s\n' "$SCAN_PATHS"

# 1. Task statuses -------------------------------------------------------------
sep; echo "1. TASK STATUSES  (valid: $VALID_STATUSES)"; echo
g_oh "$STATUS_RE" | grep -oE '[a-z_]+$' | sort | uniq -c | sort -rn |
while read -r count val; do
  case " $VALID_STATUSES " in
    *" $val "*) printf '   ok     %4s  %s\n' "$count" "$val" ;;
    *)          printf '   DRIFT  %4s  %s   <-- not a valid TaskUpdate status\n' "$count" "$val" ;;
  esac
done
for val in $(g_oh "$STATUS_RE" | grep -oE '[a-z_]+$' | sort -u); do
  case " $VALID_STATUSES " in
    *" $val "*) : ;;
    *) echo; echo "   locations of DRIFT status '$val':"
       g_n "\bstatus=[\"']?${val}\b" | sed 's/^/     /' ;;
  esac
done

# 2. subagent_type values ------------------------------------------------------
sep; echo "2. subagent_type VALUES  (verify each is a live agent type)"; echo
g_oh "subagent_type${ASSIGN}[A-Za-z0-9_-]+" | grep -oE '[A-Za-z0-9_-]+$' |
  sort | uniq -c | sort -rn | awk '{printf "   %4s  %s\n", $1, $2}'
if [ "$VERBOSE" = 1 ]; then
  echo; echo "   locations:"; g_n "subagent_type${ASSIGN}[A-Za-z0-9_-]+" | sed 's/^/     /'
fi

# 3. Hook matchers -------------------------------------------------------------
sep; echo "3. HOOK MATCHERS  (matcher: \"...\")"; echo
g_oh "matcher${ASSIGN}[A-Za-z|_]+" | grep -oE '[A-Za-z|_]+$' |
  sort | uniq -c | sort -rn | awk '{printf "   %4s  %s\n", $1, $2}'
if [ "$VERBOSE" = 1 ]; then
  echo; echo "   locations:"; g_n "matcher${ASSIGN}[A-Za-z|_]+" | sed 's/^/     /'
fi

# 4. Hook event names ----------------------------------------------------------
sep; echo "4. HOOK EVENT NAMES"; echo
EVENTS='SessionStart|SessionEnd|PreToolUse|PostToolUse|Stop|SubagentStop|UserPromptSubmit|Notification|PreCompact'
g_oh "\b(${EVENTS})\b" | sort | uniq -c | sort -rn | awk '{printf "   %4s  %s\n", $1, $2}'
if [ "$VERBOSE" = 1 ]; then
  echo; echo "   locations:"; g_n "\b(${EVENTS})\b" | sed 's/^/     /'
fi

# 5. Tool-name tokens (CamelCase) ----------------------------------------------
sep; echo "5. TOOL-NAME TOKENS  (CamelCase; verify each is a live tool)"; echo
ignore_re="$(printf '%s' "$IGNORE_TOKENS" | tr ' ' '|')"
g_oh '\b[A-Z][a-z]+([A-Z][a-z0-9]*)+\b' | grep -vxE "$ignore_re" | grep -vE "$NOISE_SUFFIX" |
  sort | uniq -c | sort -rn | awk '{printf "   %4s  %s\n", $1, $2}'
echo; echo "   (broad net — includes example/domain identifiers; verify only the tool-shaped ones)"
if [ "$VERBOSE" = 1 ]; then
  echo; echo "   locations:"
  g_n '\b[A-Z][a-z]+([A-Z][a-z0-9]*)+\b' | grep -vE "\b(${ignore_re})\b" | grep -vE "$NOISE_SUFFIX" | sed 's/^/     /'
fi

# 6. Hardcoded model names -----------------------------------------------------
# Operational text and examples must defer model choice to the user's session
# model (see subagent-driven-development > Model Selection), so a bare model name
# there is drift. Skips the meta/scope files (README, CLAUDE.md — naming the
# tuned-for target is fine), the reproduced Anthropic reference doc, and tier
# descriptors like `Opus-class`.
sep; echo "6. HARDCODED MODEL NAMES  (skills/hooks/commands/docs)"; echo
MODEL_PATHS=""
for p in skills hooks commands docs; do
  if [ -e "$p" ]; then MODEL_PATHS="$MODEL_PATHS $p"; fi
done
model_hits="$(grep -rEnI --exclude='check-tool-drift.*' --exclude='anthropic-best-practices.md' \
  '\b(Opus|Sonnet|Haiku|Fable)\b' $MODEL_PATHS 2>/dev/null |
  grep -vE '\b(Opus|Sonnet|Haiku|Fable)(/[A-Za-z]+)?-class\b' || true)"
if [ -n "$model_hits" ]; then
  echo "   REVIEW — a specific model named in operational text/examples is drift;"
  echo "   defer to the user's chosen model. Tier descriptors ('Opus-class') are allowed."
  echo
  printf '%s\n' "$model_hits" | sed 's/^/     /'
else
  echo "   none — operational text defers model choice (tier descriptors excluded)."
fi

sep
echo "Auto-checked here: statuses (1) against the enum, model names (6) against the"
echo "no-hardcode rule. For sections 2-5, confirm each name against the tools/agents"
echo "available in your current Claude Code session — ask Claude to run that diff."
