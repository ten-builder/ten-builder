#!/bin/bash
# run-agent-team.sh — Launch multiple Claude Code agents in parallel via tmux
#
# Spawns N agents side-by-side in a single tmux session, each with its own
# role prompt. Great for building full-stack apps, parallel refactors, or
# demonstrating multi-agent coding workflows.
#
# Usage:
#   ./run-agent-team.sh <prompts-dir>              # Run with prompts in a directory
#   ./run-agent-team.sh <prompts-dir> --dry        # Preview layout without running
#   ./run-agent-team.sh <prompts-dir> --skip-perms # Add --dangerously-skip-permissions
#
# Prompt directory structure:
#   prompts/
#   ├── 01-frontend.md      # Each .md file = one agent
#   ├── 02-component.md     # Files are sorted alphabetically
#   ├── 03-pages.md         # Filename becomes the pane title
#   ├── 04-data.md
#   └── 05-ux.md
#
# Environment variables:
#   CLAUDE_MODEL    Model to use (default: sonnet)
#   TMUX_SESSION    Session name (default: agent-team)
#   AGENT_DELAY     Seconds between agent launches (default: 5)
#   WORK_DIR        Working directory for agents (default: ./output)
#
# Prerequisites:
#   1. tmux:       brew install tmux
#   2. Claude Code: npm install -g @anthropic-ai/claude-code
#
# Layout (5 agents):
#   ┌────────────┬─────────────┬────────────┐
#   │  Agent 1   │  Agent 2    │  Agent 3   │
#   ├─────────────┴──────┬──────┴────────────┤
#   │     Agent 4        │     Agent 5       │
#   └────────────────────┴────────────────────┘
#
# Layout adapts automatically:
#   2 agents → side by side
#   3 agents → 2 top + 1 bottom
#   4 agents → 2x2 grid
#   5 agents → 3 top + 2 bottom
#   6 agents → 3x2 grid

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
MODEL="${CLAUDE_MODEL:-sonnet}"
SESSION="${TMUX_SESSION:-agent-team}"
DELAY="${AGENT_DELAY:-5}"
SKIP_PERMS=false

# ─── Parse arguments ─────────────────────────────────────────
PROMPTS_DIR=""
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry)       DRY_RUN=true ;;
    --skip-perms) SKIP_PERMS=true ;;
    --help|-h)
      sed -n '2,44p' "$0" | sed 's/^# //; s/^#$//'
      exit 0
      ;;
    *)
      if [[ -z "$PROMPTS_DIR" ]]; then
        PROMPTS_DIR="$arg"
      else
        echo "Error: unexpected argument '$arg'" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$PROMPTS_DIR" ]]; then
  echo "Usage: $0 <prompts-dir> [--dry] [--skip-perms]"
  echo "  Run '$0 --help' for details."
  exit 1
fi

if [[ ! -d "$PROMPTS_DIR" ]]; then
  echo "Error: prompts directory not found: $PROMPTS_DIR" >&2
  exit 1
fi

# Resolve to absolute path so prompts are accessible from any working directory
PROMPTS_DIR="$(cd "$PROMPTS_DIR" && pwd)"

# ─── Discover prompt files ───────────────────────────────────
PROMPT_FILES=()
while IFS= read -r f; do
  PROMPT_FILES+=("$f")
done < <(find "$PROMPTS_DIR" -maxdepth 1 -name '*.md' | sort)

AGENT_COUNT=${#PROMPT_FILES[@]}
if [[ $AGENT_COUNT -eq 0 ]]; then
  echo "Error: no .md files found in $PROMPTS_DIR" >&2
  exit 1
fi

if [[ $AGENT_COUNT -gt 9 ]]; then
  echo "Error: max 9 agents supported (found $AGENT_COUNT)" >&2
  exit 1
fi

# ─── Derive agent names from filenames ───────────────────────
AGENT_NAMES=()
for f in "${PROMPT_FILES[@]}"; do
  name=$(basename "$f" .md)
  # Strip leading number prefix (e.g., "01-frontend" → "frontend")
  name=$(echo "$name" | sed 's/^[0-9]*[-_]//')
  AGENT_NAMES+=("$name")
done

# ─── Prepare output directory ────────────────────────────────
WORK_DIR="${WORK_DIR:-$(pwd)/output}"
mkdir -p "$WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

# ─── Build claude command ────────────────────────────────────
CLAUDE_CMD="claude --model $MODEL"
if [[ "$SKIP_PERMS" == true ]]; then
  CLAUDE_CMD="claude --dangerously-skip-permissions --model $MODEL"
fi

# ─── Dry run ─────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  echo "=== Dry Run ==="
  echo ""
  echo "Session:    $SESSION"
  echo "Model:      $MODEL"
  echo "Work dir:   $WORK_DIR"
  echo "Skip perms: $SKIP_PERMS"
  echo "Delay:      ${DELAY}s between agents"
  echo ""
  echo "=== Agents ($AGENT_COUNT) ==="
  echo ""
  for i in "${!PROMPT_FILES[@]}"; do
    lines=$(wc -l < "${PROMPT_FILES[$i]}" | tr -d ' ')
    echo "  [$((i+1))] ${AGENT_NAMES[$i]} — ${lines} lines (${PROMPT_FILES[$i]})"
  done
  echo ""

  # Draw layout preview
  if [[ $AGENT_COUNT -le 3 ]]; then
    TOP=$AGENT_COUNT; BOT=0
  elif [[ $AGENT_COUNT -le 6 ]]; then
    TOP=$(( (AGENT_COUNT + 1) / 2 ))
    BOT=$(( AGENT_COUNT - TOP ))
  else
    TOP=$(( (AGENT_COUNT + 2) / 3 ))
    BOT=$(( AGENT_COUNT - TOP ))
  fi

  echo "=== Layout ==="
  echo ""
  WIDTH=60
  if [[ $TOP -gt 0 ]]; then
    COL_W=$(( WIDTH / TOP ))
    printf "  ┌"
    for ((j=0; j<TOP; j++)); do
      printf '%*s' $((COL_W-1)) '' | tr ' ' '─'
      [[ $j -lt $((TOP-1)) ]] && printf "┬" || printf "┐"
    done
    echo ""
    printf "  │"
    for ((j=0; j<TOP; j++)); do
      name="${AGENT_NAMES[$j]}"
      pad=$(( COL_W - 1 - ${#name} ))
      left=$(( pad / 2 ))
      right=$(( pad - left ))
      printf '%*s%s%*s│' $left '' "$name" $right ''
    done
    echo ""
  fi
  if [[ $BOT -gt 0 ]]; then
    printf "  ├"
    COL_W_B=$(( WIDTH / BOT ))
    for ((j=0; j<BOT; j++)); do
      printf '%*s' $((COL_W_B-1)) '' | tr ' ' '─'
      [[ $j -lt $((BOT-1)) ]] && printf "┼" || printf "┤"
    done
    echo ""
    printf "  │"
    for ((j=0; j<BOT; j++)); do
      idx=$((TOP + j))
      name="${AGENT_NAMES[$idx]}"
      pad=$(( COL_W_B - 1 - ${#name} ))
      left=$(( pad / 2 ))
      right=$(( pad - left ))
      printf '%*s%s%*s│' $left '' "$name" $right ''
    done
    echo ""
    printf "  └"
    for ((j=0; j<BOT; j++)); do
      printf '%*s' $((COL_W_B-1)) '' | tr ' ' '─'
      [[ $j -lt $((BOT-1)) ]] && printf "┴" || printf "┘"
    done
    echo ""
  else
    printf "  └"
    for ((j=0; j<TOP; j++)); do
      printf '%*s' $((COL_W-1)) '' | tr ' ' '─'
      [[ $j -lt $((TOP-1)) ]] && printf "┴" || printf "┘"
    done
    echo ""
  fi
  echo ""
  echo "Run without --dry to start."
  exit 0
fi

# ─── Preflight checks ───────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo "Error: tmux not found. Install with: brew install tmux" >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: claude not found. Install with: npm install -g @anthropic-ai/claude-code" >&2
  exit 1
fi

# ─── Create tmux session ────────────────────────────────────
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION"

# ─── Split panes based on agent count ────────────────────────
# Strategy: split into top row + bottom row
if [[ $AGENT_COUNT -eq 1 ]]; then
  : # single pane, nothing to split
elif [[ $AGENT_COUNT -eq 2 ]]; then
  tmux split-window -h -t "$SESSION:0.0" -p 50
elif [[ $AGENT_COUNT -eq 3 ]]; then
  tmux split-window -v -t "$SESSION:0.0" -p 35
  tmux split-window -h -t "$SESSION:0.0" -p 50
elif [[ $AGENT_COUNT -eq 4 ]]; then
  tmux split-window -v -t "$SESSION:0.0" -p 50
  tmux split-window -h -t "$SESSION:0.0" -p 50
  tmux split-window -h -t "$SESSION:0.1" -p 50
elif [[ $AGENT_COUNT -eq 5 ]]; then
  # 3 top + 2 bottom
  tmux split-window -v -t "$SESSION:0.0" -p 40
  tmux split-window -h -t "$SESSION:0.0" -p 67
  tmux split-window -h -t "$SESSION:0.2" -p 50
  tmux split-window -h -t "$SESSION:0.1" -p 50
elif [[ $AGENT_COUNT -eq 6 ]]; then
  # 3 top + 3 bottom
  tmux split-window -v -t "$SESSION:0.0" -p 50
  tmux split-window -h -t "$SESSION:0.0" -p 67
  tmux split-window -h -t "$SESSION:0.2" -p 50
  tmux split-window -h -t "$SESSION:0.1" -p 67
  tmux split-window -h -t "$SESSION:0.4" -p 50
elif [[ $AGENT_COUNT -ge 7 ]]; then
  # For 7-9: create a grid, top-heavy
  TOP_COUNT=$(( (AGENT_COUNT + 1) / 2 ))
  BOT_COUNT=$(( AGENT_COUNT - TOP_COUNT ))

  # Vertical split
  tmux split-window -v -t "$SESSION:0.0" -p 50

  # Split top row
  for ((i=1; i<TOP_COUNT; i++)); do
    pct=$(( 100 - 100 / (TOP_COUNT - i + 1) ))
    tmux split-window -h -t "$SESSION:0.0" -p "$pct" 2>/dev/null || true
  done

  # Split bottom row
  for ((i=1; i<BOT_COUNT; i++)); do
    pct=$(( 100 - 100 / (BOT_COUNT - i + 1) ))
    tmux split-window -h -t "$SESSION:0.1" -p "$pct" 2>/dev/null || true
  done
fi

# ─── Map logical agent index → tmux pane index ──────────────
# tmux pane numbering after splits can be non-sequential.
# We collect actual pane IDs to ensure correct mapping.
PANE_IDS=()
while IFS= read -r pid; do
  PANE_IDS+=("$pid")
done < <(tmux list-panes -t "$SESSION" -F '#{pane_id}')

# ─── Configure pane appearance ───────────────────────────────
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #{pane_title} "
tmux set-option -t "$SESSION" pane-border-style "fg=#64748B"
tmux set-option -t "$SESSION" pane-active-border-style "fg=#22D3EE"

# ─── Set pane titles and initialize working directory ────────
for i in "${!PANE_IDS[@]}"; do
  if [[ $i -lt $AGENT_COUNT ]]; then
    tmux select-pane -t "${PANE_IDS[$i]}" -T "${AGENT_NAMES[$i]}"
    tmux send-keys -t "${PANE_IDS[$i]}" "cd '$WORK_DIR'" Enter
  fi
done
sleep 1

# ─── Launch agents ───────────────────────────────────────────
echo "Launching $AGENT_COUNT agents..."

for i in "${!PROMPT_FILES[@]}"; do
  pane="${PANE_IDS[$i]}"
  prompt_file="${PROMPT_FILES[$i]}"
  name="${AGENT_NAMES[$i]}"

  echo "  [$((i+1))/$AGENT_COUNT] Starting $name..."

  # Start Claude Code in the pane
  tmux send-keys -t "$pane" "$CLAUDE_CMD" Enter
  sleep "$DELAY"

  # Send the prompt (read from file)
  tmux send-keys -t "$pane" \
    "Read the file $prompt_file and execute all instructions in it." Enter

  # Small gap before next agent
  if [[ $i -lt $((AGENT_COUNT - 1)) ]]; then
    sleep 2
  fi
done

echo ""
echo "All $AGENT_COUNT agents are running. Attaching to tmux session '$SESSION'..."
echo ""
echo "Useful tmux shortcuts:"
echo "  Ctrl+B then arrow keys  — switch between panes"
echo "  Ctrl+B then z           — zoom into current pane"
echo "  Ctrl+B then d           — detach (agents keep running)"
echo "  tmux attach -t $SESSION — reattach later"
echo ""
sleep 1

tmux attach -t "$SESSION"
