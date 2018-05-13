#!/bin/bash -e
#
# Provision Ubuntu VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

DISTRO_CODENAME=$(lsb_release -cs)

# Ordered list of Ubuntu releases, first being the latest, for later checks...
DISTRO_CODENAMES=($(curl -sSL http://releases.ubuntu.com/ \
                        | perl -lne 'print lc($1) if /href=[^>]+>\s*Ubuntu\s+[0-9.]+\s+(?:LTS\s+)?\(\s*([a-z]+)\s+/i'))

# Getting the above list by parsing some random webpage is brittle and may fail in the future...
if [ "${#DISTRO_CODENAMES[@]}" -lt 2 ]; then
    echo "ERROR: Couldn't fetch the list of Ubuntu releases. Provisioning might not complete successfully." >&2
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update

#
# Updating the system requires a restart. If the "vagrant-vbguest" plugin is
# installed and the updates included the kernel package, this will trigger a
# reinstallation of the VirtualBox Guest Tools for the new kernel.
#
if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y dist-upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y autoremove
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
    avahi-daemon mlocate rsync lsof iotop htop \
    ntpdate pv tree vim screen tmux ltrace strace \
    curl apt-transport-https dnsutils

# This is just a matter of preference...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install netcat-openbsd
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y purge netcat-traditional

# Minimize the number of running daemons...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y purge \
    lxcfs snapd open-iscsi mdadm accountsservice acpid

# Set a local timezone (the default for Ubuntu boxes is GMT)...
sudo timedatectl set-timezone "Europe/Lisbon"
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

sudo systemctl -q enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon 2>/dev/null
sudo systemctl start avahi-daemon
echo "VM available from the host at: ${HOSTNAME}.local"

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
    pushd "${HOME}/.ssh" >/dev/null

    if [ ! -f .authorized_keys.vagrant ]; then
        cp authorized_keys .authorized_keys.vagrant
    fi

    cat .authorized_keys.vagrant /tmp/id_rsa.pub > authorized_keys
    chmod 0600 authorized_keys
    rm -f /tmp/id_rsa.pub

    popd >/dev/null
fi

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -a --exclude=.DS_Store "${HOME}/shared/vagrant/skel/" "${HOME}/"


echo "provision.sh: Configuring custom repositories..."

# NGINX mainline gives us an updated (but production-ready) version...
curl -fsSL "https://nginx.org/keys/nginx_signing.key" | sudo apt-key add -
sudo tee "/etc/apt/sources.list.d/nginx-mainline.list" >/dev/null <<EOF
deb https://nginx.org/packages/mainline/ubuntu/ ${DISTRO_CODENAME} nginx
deb-src https://nginx.org/packages/mainline/ubuntu/ ${DISTRO_CODENAME} nginx
EOF

sudo tee "/etc/apt/preferences.d/nginx-pinning" >/dev/null <<EOF
Package: *
Pin: origin "nginx.org"
Pin-Priority: 1001
EOF


#
# For container-based projects, we'll want to use the official Docker packages...
#
# Use packages for the previous Ubuntu release if the current one isn't supported yet.
# Docker upstream takes a while to catch up, as they don't rebuild existing packages.
#
DOCKER_POOL="https://download.docker.com/linux/ubuntu/dists/${DISTRO_CODENAME}/pool/stable/amd64/"
DOCKER_DISTRO_CODENAME="$DISTRO_CODENAME"

if [ "$DISTRO_CODENAME" = "${DISTRO_CODENAMES[0]}" ] && ! curl -sSL "$DOCKER_POOL" | grep -q "\.deb"; then
    DOCKER_DISTRO_CODENAME="${DISTRO_CODENAMES[1]}"
    echo "No Docker packages for '${DISTRO_CODENAME}' release, using '${DOCKER_DISTRO_CODENAME}' instead." >&2
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install bridge-utils
curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo apt-key add -
sudo tee "/etc/apt/sources.list.d/docker-stable.list" >/dev/null <<EOF
deb [arch=amd64] https://download.docker.com/linux/ubuntu ${DOCKER_DISTRO_CODENAME} stable
EOF

sudo tee "/etc/apt/preferences.d/docker-pinning" >/dev/null <<EOF
Package: *
Pin: origin "download.docker.com"
Pin-Priority: 1001
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

if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    echo "*** Updates (may) have been installed. The guest VM should be restarted ASAP. ***" >&2
fi


# vim: set expandtab ts=4 sw=4:
