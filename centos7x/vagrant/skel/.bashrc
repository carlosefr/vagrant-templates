# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# Don't clobber titles for GNU Screen (and tmux) windows
if [[ "$TERM" == screen* ]]; then
    unset PROMPT_COMMAND
fi

# Disable programmable completion
complete -r

# User specific aliases and functions
function screen {
    if [ -z "$STY" ] && [ $# -eq 0 ]; then
        /usr/bin/env screen -d -R
    else
        /usr/bin/env screen "$@"
    fi
}
