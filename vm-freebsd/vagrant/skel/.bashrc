# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups

# enable color support of ls
export CLICOLOR=1

# set a fancy prompt (non-color)
PS1='[\u@\h \W]\$ '

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
	PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'
	;;
*)
	;;
esac

# Disable programmable completion
complete -r

# enable color support of grep
export GREP_OPTIONS='--color=auto'

# aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias z='ls -laF'

export EDITOR="vim"

# Use a color scheme closer to the one used on Linux...
export LSCOLORS="ExGxCxdaCxDxDxhbaDecec"

# functions
function screen {
	if [ -z "$STY" ] && [ $# -eq 0 ]; then
		/usr/bin/env screen -d -R
	else
		/usr/bin/env screen "$@"
	fi
}
