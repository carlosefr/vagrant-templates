#!/bin/bash -e
#
# Provision Fedora VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

sudo dnf -q -y --refresh makecache

#
# Updating the system requires a restart. If the "vagrant-vbguest" plugin is
# installed and the updates included the kernel package, this will trigger a
# reinstallation of the VirtualBox Guest Tools for the new kernel.
#
# Also, the "vagrant-reload" plugin may be used to ensure the VM is restarted
# immediately after provisioning, but it fails sometimes and I don't know why.
#
if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    sudo dnf -q -y --setopt=deltarpm=false upgrade
fi

# This is required to avoid a conflict with "vim" below... :(
sudo dnf -q -y upgrade vim-minimal
sudo dnf -q -y install \
    avahi mlocate lsof iotop htop nmap-ncat \
    ntpdate pv tree vim tmux ltrace strace \
    sysstat perf zip unzip

# For these VMs, prefer a simpler time daemon...
sudo dnf -q -y remove chrony || true
sudo systemctl -q --now enable systemd-timesyncd.service

# Set a local timezone (default is UTC)...
sudo timedatectl set-timezone "Europe/Lisbon"
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q --now enable avahi-daemon.service
echo "VM available from the host at: ${HOSTNAME}.local"

# Prevent locale from being forwarded from the host, causing issues...
if sudo grep -q '^AcceptEnv\s.*LC_' /etc/ssh/sshd_config; then
    sudo sed -i 's/^\(AcceptEnv\s.*LC_\)/#\1/' /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
fi

# Generate the initial "locate" DB...
sudo systemctl start mlocate-updatedb.service

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

# NGINX mainline gives us an updated version (using the RHEL7 packages)...
sudo rpm --import "https://nginx.org/keys/nginx_signing.key"
sudo tee "/etc/yum.repos.d/nginx-mainline.repo" >/dev/null <<EOF
[nginx-mainline]
name=NGINX Mainline
baseurl=https://nginx.org/packages/mainline/rhel/7/\$basearch/
gpgcheck=1
enabled=1
EOF

# For container-based projects, we'll want to use the official Docker packages...
sudo dnf -q -y install bridge-utils
sudo rpm --import "https://download.docker.com/linux/fedora/gpg"
sudo dnf config-manager --add-repo "https://download.docker.com/linux/fedora/docker-ce.repo"

# No packages from the above repositories have been installed,
# but prepare things for that to (maybe) happen further below...
sudo dnf -q -y makecache


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo dnf -q -y install \
    git gcc gcc-c++ automake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"

if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    echo "*** Updates (may) have been installed. The guest VM should be restarted ASAP. ***" >&2
fi


# vim: set expandtab ts=4 sw=4:
