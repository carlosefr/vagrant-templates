#!/bin/bash -eu
#
# Provision Fedora VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

if rpm -q --quiet fedora-release-cloud; then  # ...the package has been split since Fedora 30.
    readonly FEDORA_RELEASE="$(rpm -q --queryformat '%{VERSION}' fedora-release-cloud)"
else
    readonly FEDORA_RELEASE="$(rpm -q --queryformat '%{VERSION}' fedora-release)"
fi

# Fix DNS breakage on reprovisioning (sometimes)...
sudo systemctl restart NetworkManager

# Ensure DNF chooses a decent mirror, otherwise things may be *very* slow...
if ! grep -q "fastestmirror=true" /etc/dnf/dnf.conf; then
    sudo tee -a /etc/dnf/dnf.conf >/dev/null <<< "fastestmirror=true"
fi

sudo rm -f /var/cache/dnf/fastestmirror.cache
sudo dnf -q clean expire-cache
sudo dnf -q makecache

# This is required to avoid a conflict with "vim" below... :(
sudo dnf -q -y upgrade vim-minimal
sudo dnf -q -y install \
    avahi mlocate lsof iotop htop nmap-ncat \
    ntpdate pv tree vim tmux ltrace strace \
    sysstat perf zip unzip bind-utils pciutils

# Set a local timezone (default is UTC)...
sudo timedatectl set-timezone "Europe/Lisbon"
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon.service
sudo systemctl -q start avahi-daemon.service
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


echo "provision.sh: Configuring custom repositories..."

# Ensure we always have the latest NGINX version available...
sudo rpm --import "https://nginx.org/keys/nginx_signing.key"
sudo tee "/etc/yum.repos.d/nginx-mainline.repo" >/dev/null <<EOF
[nginx-mainline]
name=nginx.org (mainline)
baseurl=https://nginx.org/packages/mainline/centos/8/\$basearch/
gpgcheck=1
enabled=1
priority=10
module_hotfixes=1
EOF

# For container-based projects, we'll want to use the official Docker packages...
sudo dnf -q -y install bridge-utils
sudo rpm --import "https://download.docker.com/linux/fedora/gpg"
sudo dnf config-manager --add-repo "https://download.docker.com/linux/fedora/docker-ce.repo"

# If this version of Fedora isn't supported yet, use packages intended for the previous one...
if ! curl -sSL "https://download.docker.com/linux/fedora/${FEDORA_RELEASE}/source/stable/Packages/" | cat | grep -q "\.src\.rpm"; then
    echo "No upstream Docker CE packages for Fedora ${FEDORA_RELEASE}, using packages for Fedora $((FEDORA_RELEASE-1)) instead." >&2
    sudo sed -i "s|/fedora/\$releasever|/fedora/$((FEDORA_RELEASE-1))|g" /etc/yum.repos.d/docker-ce.repo
else  # ...reverse on reprovision.
    sudo sed -i "s|/fedora/$((FEDORA_RELEASE-1))|/fedora/\$releasever|g" /etc/yum.repos.d/docker-ce.repo
fi

# Docker already supports cgroup v2 since v20.10, do nothing if sufficiently recent...
if [[ ${FEDORA_RELEASE} -ge 31 && ${FEDORA_RELEASE} -le 32 ]]; then
    echo "Configuring kernel to use cgroup v1. Fedora ${FEDORA_RELEASE} selects cgroup v2 by default but Docker doesn't support it." >&2
    sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
fi

# No packages from the above repositories have been installed,
# but prepare things for that to (maybe) happen further below...
sudo dnf -q clean expire-cache
sudo dnf -q -y makecache


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo dnf -q -y install \
    git gcc gcc-c++ automake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
