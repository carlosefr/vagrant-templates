#!/bin/bash -eu
#
# Provision RHEL-like VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


readonly OS_RELEASE="$(rpm -q --queryformat '%{VERSION}' "$(rpm -qf /etc/redhat-release)" | cut -d. -f1)"
readonly OS_VARIANT="$(sed -E 's/^(.+)\s+release.*$/\1/' /etc/redhat-release)"


echo "provision.sh: Customizing the base system (${OS_VARIANT} ${OS_RELEASE})..."

sudo dnf -q clean expire-cache
sudo dnf -q -y makecache

# EPEL gives us some essential base-system extras...
sudo dnf -q -y --nogpgcheck install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_RELEASE}.noarch.rpm" || true
sudo rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-${OS_RELEASE}"

sudo dnf -q -y install \
    rsync avahi nss-mdns mlocate lsof iotop \
    htop nmap-ncat pv tree vim tmux ltrace strace \
    sysstat perf zip unzip bind-utils man-pages

# Minor cleanup...
sudo systemctl stop firewalld.service
sudo systemctl -q disable firewalld.service

# Match the vagrant host's timezone...
sudo timedatectl set-timezone "${HOST_TIMEZONE:-"Europe/Lisbon"}" || true
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon.service
sudo systemctl start avahi-daemon.service

# Prevent locale from being forwarded from the host, causing issues...
if sudo grep -q '^AcceptEnv\s.*LC_' /etc/ssh/sshd_config; then
    sudo sed -i 's/^\(AcceptEnv\s.*LC_\)/#\1/' /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
fi

# Generate the initial "locate" DB...
sudo systemctl start mlocate-updatedb.service

# Some SELinux tools may complain if this file is missing...
sudo touch /etc/selinux/targeted/contexts/files/file_contexts.local

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
echo -n | sudo tee /etc/motd >/dev/null


echo "provision.sh: Configuring custom repositories..."

# NGINX mainline gives us an updated (but production-ready) version...
sudo rpm --import "https://nginx.org/keys/nginx_signing.key"
sudo tee "/etc/yum.repos.d/nginx-mainline.repo" >/dev/null <<EOF
[nginx-mainline]
name=nginx.org (mainline)
baseurl=https://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
priority=10
module_hotfixes=1
EOF

# For container-based projects, we'll want to keep using the official Docker
# packages for the time being, instead of switching to podman/buildah...
sudo rpm --import "https://download.docker.com/linux/centos/gpg"
sudo tee "/etc/yum.repos.d/docker-ce-stable.repo" >/dev/null <<EOF
[docker-ce-stable]
name=Docker CE (stable)
baseurl=https://download.docker.com/linux/centos/\$releasever/\$basearch/stable
gpgcheck=1
enabled=1
priority=10
module_hotfixes=1
EOF

# If this RHEL version isn't supported yet, use packages intended for the previous one...
if ! curl -sSL "https://download.docker.com/linux/centos/${OS_RELEASE}/source/stable/Packages/" | cat | grep -q "\.src\.rpm"; then
    echo "No upstream Docker CE packages for ${OS_VARIANT} ${OS_RELEASE}, using packages for ${OS_VARIANT} $((OS_RELEASE-1)) instead." >&2
    sudo sed -i "s|/centos/\$releasever|/centos/$((OS_RELEASE-1))|g" /etc/yum.repos.d/docker-ce-stable.repo
else  # ...reverse on reprovision.
    sudo sed -i "s|/centos/$((OS_RELEASE-1))|/centos/\$releasever|g" /etc/yum.repos.d/docker-ce-stable.repo
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
