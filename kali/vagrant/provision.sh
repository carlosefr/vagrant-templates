#!/bin/bash -eu
#
# Provision Kali VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
    htop iotop pv ltrace strace moreutils bvi

# Match the vagrant host's timezone if known (i.e. probably won't work on Windows hosts)...
if timedatectl list-timezones | grep -qxF "${HOST_TIMEZONE:-"UTC"}"; then
    sudo timedatectl set-timezone "${HOST_TIMEZONE:-"UTC"}" || true
else
    sudo timedatectl set-timezone UTC || true
fi

echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

sudo systemctl -q enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon 2>/dev/null
sudo systemctl start avahi-daemon

# Prevent locale from being forwarded from the host, causing issues...
if sudo grep -q '^AcceptEnv\s.*LC_' /etc/ssh/sshd_config; then
    sudo sed -i 's/^\(AcceptEnv\s.*LC_\)/#\1/' /etc/ssh/sshd_config
fi

sudo systemctl restart ssh

# Generate the initial "locate" DB...
if sudo test -x /etc/cron.daily/plocate; then
    sudo /etc/cron.daily/plocate
fi

# If another (file) provisioner made the host user's credentials available
# to us (see the "Vagrantfile" for details), let it use "scp" and stuff...
if ls -1 /tmp | grep -qE '^id_[^.]+\.pub$'; then
    pushd "${HOME}/.ssh" >/dev/null

    if [[ ! -f .authorized_keys.vagrant ]]; then
        cp authorized_keys .authorized_keys.vagrant
    fi

    cat .authorized_keys.vagrant /tmp/id_*.pub > authorized_keys
    chmod 0600 authorized_keys
    rm -f /tmp/id_*.pub

    popd >/dev/null
fi

# I'm old school, no fancy command colors and things...
sudo chsh -s /bin/bash "$(id -un)"
rm -f "${HOME}/.bashrc.original"

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -r --exclude=.DS_Store "${HOME}/shared/vagrant/skel/" "${HOME}/"

# Disable verbose messages on login...
echo -n > "${HOME}/.hushlogin"


echo "provision.sh: Running project-specific actions..."

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
