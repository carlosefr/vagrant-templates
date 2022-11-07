#!/bin/bash -eu
#
# Provision CentOS VMs (vagrant shell provisioner, CentOS >= 8).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision-v8.sh: Customizing the base system..."

readonly CENTOS_RELEASE="$(rpm -q --queryformat '%{VERSION}' "$(rpm -qf /etc/centos-release)" | cut -d. -f1)"

sudo rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial"

sudo dnf -q clean expire-cache
sudo dnf -q -y makecache

# EPEL gives us some essential base-system extras...
sudo dnf -q -y --nogpgcheck install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${CENTOS_RELEASE}.noarch.rpm" || true
sudo rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-${CENTOS_RELEASE}"

sudo dnf -q -y install \
    avahi nss-mdns mlocate lsof iotop \
    htop nmap-ncat pv tree vim tmux ltrace strace \
    sysstat perf zip unzip bind-utils man-pages

# Minor cleanup...
sudo systemctl stop tuned.service firewalld.service
sudo systemctl -q disable tuned.service firewalld.service

# Set a local timezone (the default for CentOS boxes is EDT)...
sudo timedatectl set-timezone "Europe/Lisbon"
echo "VM local timezone: $(timedatectl | awk '/[Tt]ime\s+zone:/ {print $3}')"

sudo systemctl -q enable chronyd.service
sudo systemctl start chronyd.service

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon.service
sudo systemctl start avahi-daemon.service
echo "VM available from the host at: ${HOSTNAME}.local"

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


echo "provision-v8.sh: Configuring custom repositories..."

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

# If this version of CentOS isn't supported yet, use packages intended for the previous one...
if ! curl -sSL "https://download.docker.com/linux/centos/${CENTOS_RELEASE}/source/stable/Packages/" | cat | grep -q "\.src\.rpm"; then
    echo "No upstream Docker CE packages for CentOS ${CENTOS_RELEASE}, using packages for CentOS $((CENTOS_RELEASE-1)) instead." >&2
    sudo sed -i "s|/centos/\$releasever|/centos/$((CENTOS_RELEASE-1))|g" /etc/yum.repos.d/docker-ce-stable.repo
else  # ...reverse on reprovision.
    sudo sed -i "s|/centos/$((CENTOS_RELEASE-1))|/centos/\$releasever|g" /etc/yum.repos.d/docker-ce-stable.repo
fi


# No packages from the above repositories have been installed,
# but prepare things for that to (maybe) happen further below...
sudo dnf -q clean expire-cache
sudo dnf -q -y makecache


echo "provision-v8.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo dnf -q -y install \
    git gcc gcc-c++ automake

# Additional project-specific customizations...
# [...]


echo "provision-v8.sh: Done!"


# vim: set expandtab ts=4 sw=4:
