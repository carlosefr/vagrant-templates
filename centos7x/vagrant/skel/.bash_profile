# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/.local/bin:$HOME/bin
export PATH

# Make SSH agent forwarding work with GNU screen (see ".screenrc")...
if [ -S "$SSH_AUTH_SOCK" -a ! -L "$SSH_AUTH_SOCK" ]; then
	if [ ! -d "$HOME/.ssh" ]; then
		mkdir -p -m 0700 "$HOME/.ssh"
	fi

	ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
fi
