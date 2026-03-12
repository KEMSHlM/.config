#!/bin/zsh
# claude-switch.sh - claude session manager with y/n control
# Args: session_name

SESSION_NAME="${1:-}"

if ! tmux has-session -t "claude" 2>/dev/null; then
  tmux display-message "No claude session running"
  exit 0
fi

CURRENT_WINDOW=$(tmux display-message -p -t claude '#{window_name}' 2>/dev/null)

SELECTED=$(tmux list-windows -t claude -F "#{window_name} #{pane_current_command} #{pane_current_path}" | \
  while read name cmd dirpath; do
    if [ "$cmd" = "ssh" ]; then
      label="[remote] $name"
    else
      label=$(echo "$dirpath" | sed "s|$HOME|~|")
    fi
    [ "$name" = "$CURRENT_WINDOW" ] && marker="*" || marker=" "
    printf "claude:=%s\t%s %s\n" "$name" "$marker" "$label"
  done | \
  fzf \
    --delimiter='\t' \
    --with-nth=2 \
    --border rounded \
    --padding 1,2 \
    --header $'  Claude Sessions\n  Enter: open  y: yes  n: no  ctrl-x: kill\n' \
    --header-first \
    --preview 'tmux capture-pane -t {1} -p -e -S -50 2>/dev/null' \
    --preview-window 'right:60%:wrap:border-left' \
    --bind 'y:execute-silent(tmux send-keys -t {1} "y" Enter)' \
    --bind 'n:execute-silent(tmux send-keys -t {1} "n" Enter)' \
    --bind 'ctrl-x:execute-silent(tmux kill-window -t {1})+abort')

[ -z "$SELECTED" ] && exit 0

# field 1 is "claude:=window_name", extract window name
WINDOW=$(echo "$SELECTED" | cut -f1 | sed 's/claude:=//')

[ -z "$WINDOW" ] && exit 0

if [ "$SESSION_NAME" = "claude" ]; then
  tmux switch-client -t "claude:$WINDOW"
else
  tmux display-popup -w80% -h80% -E "tmux attach-session -t 'claude:$WINDOW'"
fi
