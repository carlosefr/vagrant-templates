#!/bin/sh -e
#
# Provision FreeBSD VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

sudo pkg install -q -y \
    htop lsof ltrace bash curl \
    pv tree screen tmux vim-lite

# Set a local timezone (the default for FreeBSD boxes is UTC)...
sudo tzsetup "Europe/Lisbon"
echo "VM local timezone: $(date +%Z)"

if ! grep -q '^ *ntpd_enable="YES"' /etc/rc.conf; then
    echo 'ntpd_enable="YES"' | sudo tee -a /etc/rc.conf >/dev/null
fi

if ! grep -q '^ *vboxservice_flags="--disable-timesync"' /etc/rc.conf; then
    echo 'vboxservice_flags="--disable-timesync"' | sudo tee -a /etc/rc.conf >/dev/null
fi

sudo service ntpd start || true
sudo service vboxservice restart

# Avahi gives us an easly reachable ".local" name for the VM...
sudo pkg install -q -y dbus avahi-app avahi-libdns nss_mdns
sudo sed -i '' -E 's/^ *hosts: +files +dns/hosts: files mdns dns/' /etc/nsswitch.conf

if ! grep -q '^ *dbus_enable="YES"' /etc/rc.conf; then
    echo 'dbus_enable="YES"' | sudo tee -a /etc/rc.conf >/dev/null
fi

if ! grep -q '^ *avahi_daemon_enable="YES"' /etc/rc.conf; then
    echo 'avahi_daemon_enable="YES"' | sudo tee -a /etc/rc.conf >/dev/null
fi

sudo service dbus start || true
sudo service avahi-daemon start || true
echo "VM available from the host at: $(hostname).local"

# Generate the initial "locate" DB...
sudo $(ls -1 /etc/periodic/weekly/*.locate | head -1)

# If another (file) provisioner made the host user's credentials available
# to us (see the "Vagrantfile" for details), let it use "scp" and stuff...
if [ -f /tmp/id_rsa.pub ]; then
    if [ ! -f "${HOME}/.ssh/.authorized_keys.vagrant" ]; then
        cp "${HOME}/.ssh/authorized_keys" "${HOME}/.ssh/.authorized_keys.vagrant"
    fi

    cat "${HOME}/.ssh/.authorized_keys.vagrant" /tmp/id_rsa.pub > "${HOME}/.ssh/authorized_keys"
    chmod 0600 "${HOME}/.ssh/authorized_keys"
    rm -f /tmp/id_rsa.pub
fi

# I'm sorry, but the default shell annoys me...
sudo chsh -s /usr/local/bin/bash "${USER}"

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -a --exclude=.DS_Store "${HOME}/rsynced/vagrant/skel/" "${HOME}/"


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo pkg install -q -y \
    git gmake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
