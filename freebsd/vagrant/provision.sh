#!/bin/sh -e
#
# Provision FreeBSD VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

# VirtualBox's NAT resolver does not support SRV records, which "pkg" needs to find mirrors...
if ! grep -qE '^\s*(prepend|supersede) domain-name-servers' /etc/dhclient.conf; then
    echo "prepend domain-name-servers 1.1.1.1, 1.0.0.1;" | sudo tee -a /etc/dhclient.conf >/dev/null
    sudo service dhclient restart em0
fi

sudo pkg update -qf

sudo pkg install -q -y \
    htop lsof ltrace bash curl \
    pv tree screen tmux vim rsync

# Match the vagrant host's timezone if known (i.e. probably won't work on Windows hosts)...
if [ -f "/usr/share/zoneinfo/${HOST_TIMEZONE:-"UTC"}" ]; then
    sudo tzsetup "${HOST_TIMEZONE:-"UTC"}" || true
else
    sudo tzsetup UTC || true
fi

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

# Generate the initial "locate" DB...
sudo "$(find /etc/periodic/weekly -type f -name '*.locate' | head -1)"

# If another (file) provisioner made the host user's credentials available
# to us (see the "Vagrantfile" for details), let it use "scp" and stuff...
if ls -1 /tmp | grep -qE '^id_[^.]+\.pub$'; then
    if [ ! -f "${HOME}/.ssh/.authorized_keys.vagrant" ]; then
        cp "${HOME}/.ssh/authorized_keys" "${HOME}/.ssh/.authorized_keys.vagrant"
    fi

    cat "${HOME}/.ssh/.authorized_keys.vagrant" /tmp/id_*.pub > "${HOME}/.ssh/authorized_keys"
    chmod 0600 "${HOME}/.ssh/authorized_keys"
    rm -f /tmp/id_*.pub
fi

# I'm sorry, but the default shell annoys me...
sudo chsh -s /usr/local/bin/bash "${USER}"

#
# BUG: With VirtualBox 7.0.2 (at least) the rsync command below confuses the shared
#      folder: the "shared/vagrant/skel" directory disappears and its contents appear
#      directly under "shared/vagrant" (only in the guest, not the host). This only
#      happens during the initial provisioning and doesn't seem to affect Linux VMs.
#
# Traversing the whole shared directory structure prevents the bug from triggering...
#
find "${HOME}/shared/" -print >/dev/null

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -r --exclude=.DS_Store "${HOME}/shared/vagrant/skel/" "${HOME}/"

# Disable verbose messages on login...
printf "" > "${HOME}/.hushlogin"


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo pkg install -q -y \
    git gmake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
