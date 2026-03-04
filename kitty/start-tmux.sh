#!/bin/bash

# Check for tmux in common locations
if command -v tmux >/dev/null 2>&1; then
    # Use tmux from PATH
    exec tmux "$@"
elif [ -x "/opt/homebrew/bin/tmux" ]; then
    # macOS with Homebrew
    exec /opt/homebrew/bin/tmux "$@"
elif [ -x "/usr/local/bin/tmux" ]; then
    # Alternative location
    exec /usr/local/bin/tmux "$@"
elif [ -x "/usr/bin/tmux" ]; then
    # Linux standard location
    exec /usr/bin/tmux "$@"
else
    echo "tmux not found!"
    exec /bin/zsh
fi