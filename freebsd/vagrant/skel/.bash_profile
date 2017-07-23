# ~/.bash_profile: executed by the command interpreter for login shells.

# include .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Make SSH agent forwarding work with GNU screen (see ".screenrc")...
if [ -S "$SSH_AUTH_SOCK" -a ! -L "$SSH_AUTH_SOCK" ]; then
    if [ ! -d "$HOME/.ssh" ]; then
	mkdir -p -m 0700 "$HOME/.ssh"
    fi

    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
fi
