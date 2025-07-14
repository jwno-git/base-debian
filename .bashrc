# Bash Config

# Prompt - using standard ANSI colors for better compatibility
if [[ $EUID -eq 0 ]]; then
    # Root prompt: red
    PS1=' \[\033[90m\]\w \[\033[91m\]root \[\033[91m\]>\[\033[0m\] '
else
    # User prompt: green
    PS1=' \[\033[90m\]\w \[\033[92m\]>\[\033[0m\] '
fi

# Path configuration
export PATH="$HOME/.local/scripts:$PATH"

# Environment variables
export EDITOR="vim"
export VISUAL="vim"
export GTK_THEME=Tokyonight-Dark
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

# Common aliases
alias ps='ps aux'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias ll='ls -al'

# User-specific functions (only for regular user, not root)
if [[ $EUID -ne 0 ]]; then
    # Configuration management
    update_bash() {
        echo "Updating both user and root .bashrc files..."
        sudo cp ~/.bashrc /root/.bashrc
        echo "✓ Both configs updated"
        echo "Note: Changes will take effect on next shell session or after 'source ~/.bashrc'"
    }

    # Shell Commands
    ii() {
        eog "$@" > /dev/null 2>&1 &
    }

    # Services Monitor
    service_status() {
        echo "=== FAILED SERVICES (Critical!) ==="
        systemctl list-units --type=service --state=failed --no-pager
        echo -e "\n=== RUNNING SERVICES ==="
        systemctl list-units --type=service --state=running --no-pager
        echo -e "\n=== EXITED SERVICES (One-shot completed) ==="
        systemctl list-units --type=service --state=exited --no-pager
        echo -e "\n=== INACTIVE SERVICES ==="
        systemctl list-units --type=service --state=inactive --no-pager
        echo "... (showing first 10 inactive services)"
    }
fi

# History configuration
HISTFILE=~/.bash_history
HISTSIZE=10000
HISTFILESIZE=10000
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r"

# Display configuration and fastfetch
fbset -g 2880 1800 2880 1800 32 2>/dev/null
clear

# Run fastfetch on login
if [[ -n "$DISPLAY" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
    # In GUI terminal
    if [[ $EUID -eq 0 ]]; then
        # Root fastfetch
        fastfetch --logo-type none --title-color-user 31
    else
        # User fastfetch with NixOS logo
        if [[ -f "$HOME/Pictures/Logos/nixoslogo.png" ]]; then
            fastfetch --logo-type sixel \
                      --logo "$HOME/Pictures/Logos/nixoslogo.png" \
                      --logo-height 12 \
                      --logo-width 22 \
                      --logo-padding-left 4 \
                      --logo-padding-top 2 \
                      --title-color-user 36 \
                      --color-keys magenta \
                      --title-color-host magenta
        else
            # Fallback if logo doesn't exist
            fastfetch --logo-type none \
                      --title-color-user 36 \
                      --color-keys magenta \
                      --title-color-host magenta
        fi
    fi
else
    # In TTY
    if [[ $EUID -eq 0 ]]; then
        fastfetch --logo-type none \
                  --color-keys magenta \
                  --title-color-user 36 \
                  --title-color-host magenta
    else
        fastfetch --logo-type none --title-color-user 36
    fi
fi
