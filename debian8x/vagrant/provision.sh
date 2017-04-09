#!/bin/bash -e
#
# Provision Debian VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

DISTRO_CODENAME=$(lsb_release -cs)

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update

#
# Updating the system requires a restart. If the "vagrant-vbguest" plugin is
# installed and the updates included the kernel package, this will trigger a
# reinstallation of the VirtualBox Guest Tools for the new kernel.
#
# Also, the "vagrant-reload" plugin may be used to ensure the VM is restarted
# immediately after provisioning, but it fails sometimes and I don't know why.
#
if [ "$SYSTEM_UPDATES" == "true" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y autoremove
    echo "*** Updates have been installed. The guest VM should be restarted ASAP. ***" >&2
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
    avahi-daemon mlocate rsync lsof iotop htop \
    ntpdate pv tree vim screen tmux ltrace strace \
    curl apt-transport-https

# This is just a matter of preference...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install netcat-openbsd
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y purge netcat-traditional


# Set a local timezone (the default for Debian boxes is GMT)...
sudo timedatectl set-timezone "Europe/Lisbon"

sudo systemctl -q enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon 2>/dev/null
sudo systemctl start avahi-daemon

# Prevent locale from being forwarded from the host, causing issues...
if sudo grep -q '^AcceptEnv\s.*LC_' /etc/ssh/sshd_config; then
    sudo sed -i 's/^\(AcceptEnv\s.*LC_\)/#\1/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
fi

# Generate the initial "locate" DB...
if sudo test -x /etc/cron.daily/mlocate; then
    sudo /etc/cron.daily/mlocate
fi

# Remove the spurious "you have mail" message on login...
if [ -s "/var/spool/mail/$USER" ]; then
    > "/var/spool/mail/$USER"
fi

# If another (file) provisioner made the host user's credentials available
# to us (see the "Vagrantfile" for details), let it use "scp" and stuff...
if [ -f /tmp/id_rsa.pub ]; then
    cat /tmp/id_rsa.pub >> ~/.ssh/authorized_keys
    rm -f /tmp/id_rsa.pub
fi

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -a --exclude=.DS_Store ~/shared/vagrant/skel/ ~/


echo "provision.sh: Configuring custom repositories..."

# NGINX mainline gives us an updated (but production-ready) version...
curl -fsSL "https://nginx.org/keys/nginx_signing.key" | sudo apt-key add -
sudo tee "/etc/apt/sources.list.d/nginx-mainline.list" >/dev/null <<EOF
deb https://nginx.org/packages/mainline/debian/ ${DISTRO_CODENAME} nginx
deb-src https://nginx.org/packages/mainline/debian/ ${DISTRO_CODENAME} nginx
EOF

# For container-based projects, we'll want to use the official Docker packages...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install bridge-utils
curl -fsSL "https://download.docker.com/linux/debian/gpg" | sudo apt-key add -
sudo tee "/etc/apt/sources.list.d/docker-stable.list" >/dev/null <<EOF
deb [arch=amd64] https://download.docker.com/linux/debian ${DISTRO_CODENAME} stable
EOF

# No packages from the above repositories have been installed,
# but prepare things for that to (maybe) happen further below...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
    git build-essential

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
