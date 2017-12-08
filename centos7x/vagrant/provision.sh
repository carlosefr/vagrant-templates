#!/bin/bash -e
#
# Provision CentOS VMs (vagrant shell provisioner).
#


if [ "$(id -u)" != "$(id -u vagrant)" ]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "provision.sh: Customizing the base system..."

CENTOS_RELEASE=$(rpm -q --queryformat '%{VERSION}' centos-release)

sudo rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-$CENTOS_RELEASE"

sudo yum -q -y clean all
sudo yum -q -y makecache fast

# EPEL gives us some essential base-system extras...
sudo yum -q -y --nogpgcheck install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${CENTOS_RELEASE}.noarch.rpm" || true
sudo rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-${CENTOS_RELEASE}"

#
# Updating the system requires a restart. If the "vagrant-vbguest" plugin is
# installed and the updates included the kernel package, this will trigger a
# reinstallation of the VirtualBox Guest Tools for the new kernel.
#
if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    sudo yum -q -y update
fi

sudo yum -q -y install \
    avahi chrony mlocate net-tools yum-utils lsof iotop \
    htop nmap-ncat ntpdate pv tree vim tmux ltrace strace \
    sysstat perf zip unzip bind-utils

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
if sudo test -x /etc/cron.daily/mlocate; then
    sudo /etc/cron.daily/mlocate
fi

# Some SELinux tools may complain if this file is missing...
sudo touch /etc/selinux/targeted/contexts/files/file_contexts.local

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

# IUS gives us recent (but stable) packages...
sudo yum -q -y --nogpgcheck install "https://centos${CENTOS_RELEASE}.iuscommunity.org/ius-release.rpm" || true
sudo rpm --import "/etc/pki/rpm-gpg/IUS-COMMUNITY-GPG-KEY"

# NGINX mainline gives us an updated (but production-ready) version...
sudo rpm --import "https://nginx.org/keys/nginx_signing.key"
sudo tee "/etc/yum.repos.d/nginx-mainline.repo" >/dev/null <<EOF
[nginx-mainline]
name=NGINX Mainline
baseurl=https://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
EOF

# For container-based projects, we'll want to use the official Docker packages...
sudo yum -q -y install bridge-utils
sudo rpm --import "https://download.docker.com/linux/centos/gpg"
sudo yum-config-manager --add-repo "https://download.docker.com/linux/centos/docker-ce.repo"

# No packages from the above repositories have been installed,
# but prepare things for that to (maybe) happen further below...
sudo yum -q -y makecache fast


echo "provision.sh: Running project-specific actions..."

# Install extra packages needed for the project...
sudo yum -q -y install \
    git gcc gcc-c++ automake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"

if [ "$INSTALL_SYSTEM_UPDATES" == "true" ]; then
    echo "*** Updates (may) have been installed. The guest VM should be restarted ASAP. ***" >&2
fi


# vim: set expandtab ts=4 sw=4:
