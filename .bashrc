# Bash Config

# Prompt - using standard ANSI colors for better compatibility
if [[ $EUID -eq 0 ]]; then
    # Root prompt: red
    PS1=' \[\033[90m\]\w \[\033[91m\]root \[\033[36m\]>\[\033[0m\] '
else
    # User prompt: cyan
    PS1=' \[\033[90m\]\w \[\033[36m\]>\[\033[0m\] '
fi

# Path configuration
export PATH="$HOME/.local/scripts:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Environment variables
export EDITOR="vim"
export VISUAL="vim"

# Common aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

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

    # Custom snapshot with description
    snap() {
        if [ -z "$1" ]; then 
            echo "Usage: snap <description>"
            echo "Example: snap BaseInstall"
            return 1
        fi
        sudo btrfs subvolume snapshot / "/.snapshots/$1" && \
        echo "✓ Created snapshot: $1"
    }

    # List snapshots using native btrfs command
    snapl() {
        sudo btrfs subvolume list /.snapshots
    }

    # Remove snapshot
    snaprm() {
        if [ -z "$1" ]; then
            echo "Usage: snaprm <snapshot_name>"
            echo "Available snapshots:"
            sudo find /.snapshots -maxdepth 1 -type d -printf "  %f\n" | grep -v "^  $"
            return 1
        fi
        if [ ! -d "/.snapshots/$1" ]; then
            echo "Error: Snapshot '$1' does not exist"
            return 1
        fi
        echo "Removing snapshot: $1"
        sudo btrfs subvolume delete "/.snapshots/$1" && \
        echo "✓ Removed snapshot: $1"
    }

    # Show snapshot disk usage
    snapdu() {
        echo "=== Snapshot Disk Usage ==="
        if [ -n "$1" ]; then
            # Show usage for specific snapshot
            echo "Usage for snapshot: $1"
            sudo du -sh "/.snapshots/$1" 2>/dev/null || \
            echo "Snapshot '$1' not found"
        else
            # Show usage for all snapshots
            echo "Individual snapshot sizes:"
            sudo find /.snapshots -maxdepth 1 -type d -name "*" | \
            while read -r dir; do
                if [ "$dir" != "/.snapshots" ]; then
                    local name=$(basename "$dir")
                    local size=$(sudo du -sh "$dir" 2>/dev/null | cut -f1)
                    printf "  %-20s %s\n" "$name" "$size"
                fi
            done
            echo ""
            echo "Total snapshots directory size:"
            sudo du -sh /.snapshots
        fi
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
        if [[ -f "$HOME/Pictures/Logos/debianroot.png" ]]; then
        fastfetch --logo-type chafa \
                  --logo "$HOME/Pictures/Logos/debianroot.png" \
                  --logo-height 12 \
                  --logo-width 22 \
                  --logo-padding-left 4 \
                  --logo-padding-top 2 
        else
            # Fallback if logo doesn't exist
            fastfetch --logo-type none 
        fi
    else
        # User fastfetch
        if [[ -f "$HOME/Pictures/Logos/debian.png" ]]; then
            fastfetch --logo-type chafa \
                      --logo "$HOME/Pictures/Logos/debian.png" \
                      --logo-height 12 \
                      --logo-width 22 \
                      --logo-padding-left 4 \
                      --logo-padding-top 2
        else
            # Fallback if logo doesn't exist
            fastfetch --logo-type none 
        fi
    fi
else
    # In TTY
    if [[ $EUID -eq 0 ]]; then
        fastfetch --logo-type none 
    fi
fi

# BLE Completion/Command Verification
# Only load in interactive shells
if [[ $- == *i* ]]; then
    [[ -f /usr/local/share/blesh/ble.sh ]] && source /usr/local/share/blesh/ble.sh
fi

# BLE color configuration
if [[ ${BLE_VERSION-} ]]; then
    ble-color-setface command_function "fg=32"
    ble-color-setface command_builtin "fg=32"
    ble-color-setface command_alias "fg=32"
    ble-color-setface command_file "fg=32"
    ble-color-setface syntax_error "fg=31"
fi
