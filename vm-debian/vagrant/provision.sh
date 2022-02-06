#!/bin/bash -eu
#
# Provision Debian VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

readonly DISTRO_CODENAME="$(lsb_release -cs)"

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq --allow-releaseinfo-change update

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install \
    avahi-daemon mlocate rsync lsof iotop htop \
    ntpdate pv tree vim screen tmux ltrace strace \
    curl apt-transport-https dnsutils

# This is just a matter of preference...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install netcat-openbsd
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y purge netcat-traditional


# Set a local timezone (the default for Debian boxes is GMT)...
sudo timedatectl set-timezone "Europe/Lisbon"
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime +zone:/ {print $3}')"

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
if [[ -s "/var/spool/mail/${USER}" ]]; then
    echo -n > "/var/spool/mail/${USER}"
fi

# If another (file) provisioner made the host user's credentials available
# to us (see the "Vagrantfile" for details), let it use "scp" and stuff...
if [[ -f /tmp/id_rsa.pub ]]; then
    pushd "${HOME}/.ssh" >/dev/null

    if [[ ! -f .authorized_keys.vagrant ]]; then
        cp authorized_keys .authorized_keys.vagrant
    fi

    cat .authorized_keys.vagrant /tmp/id_rsa.pub > authorized_keys
    chmod 0600 authorized_keys
    rm -f /tmp/id_rsa.pub

    popd >/dev/null
fi

# Make "vagrant ssh" sessions more comfortable by tweaking the
# configuration of some system utilities (eg. bash, vim, tmux)...
rsync -r --exclude=.DS_Store "${HOME}/shared/vagrant/skel/" "${HOME}/"
sudo rm -f /etc/update-motd.d/99-bento && echo -n | sudo tee /etc/motd >/dev/null

# Disable verbose messages on login...
echo -n > "${HOME}/.hushlogin"


echo "provision.sh: Configuring custom repositories..."

# NGINX mainline gives us an updated (but production-ready) version...
curl -fsSL "https://nginx.org/keys/nginx_signing.key" \
    | gpg --dearmor \
    | sudo tee "/usr/share/keyrings/nginx-archive-keyring.gpg" >/dev/null

sudo tee "/etc/apt/sources.list.d/nginx-mainline.list" >/dev/null <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian/ ${DISTRO_CODENAME} nginx
deb-src [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian/ ${DISTRO_CODENAME} nginx
EOF

sudo tee "/etc/apt/preferences.d/nginx-pinning" >/dev/null <<EOF
Package: *
Pin: origin "nginx.org"
Pin-Priority: 1001
EOF


# For container-based projects, we'll want to use the official Docker packages...
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y install bridge-utils

curl -fsSL "https://download.docker.com/linux/debian/gpg" \
    | gpg --dearmor \
    | sudo tee "/usr/share/keyrings/docker-stable-archive-keyring.gpg" >/dev/null

sudo tee "/etc/apt/sources.list.d/docker-stable.list" >/dev/null <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/docker-stable-archive-keyring.gpg] https://download.docker.com/linux/debian ${DISTRO_CODENAME} stable
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


# vim: set expandtab ts=4 sw=4:
