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
# Also, the "vagrant-reload" plugin may be used to ensure the VM is restarted
# immediately after provisioning, but it fails sometimes and I don't know why.
#
if [ "$SYSTEM_UPDATES" == "true" ]; then
    sudo yum -q -y update
    echo "*** Updates have been installed. The guest VM should be restarted ASAP. ***" >&2
fi

sudo yum -q -y install \
    avahi chrony mlocate net-tools yum-utils lsof iotop \
    htop nmap-ncat ntpdate pv tree vim tmux ltrace strace \
    sysstat perf zip unzip

# Minor cleanup...
sudo systemctl stop tuned firewalld
sudo systemctl -q disable tuned firewalld

# Set a local timezone (the default for CentOS boxes is EDT)...
sudo timedatectl set-timezone "Europe/Lisbon"

sudo systemctl -q enable chronyd
sudo systemctl start chronyd

# This gives us an easly reachable ".local" name for the VM...
sudo systemctl -q enable avahi-daemon
sudo systemctl start avahi-daemon

# Prevent locale from being forwarded from the host, causing issues...
if sudo grep -q '^AcceptEnv\s.*LC_' /etc/ssh/sshd_config; then
    sudo sed -i 's/^\(AcceptEnv\s.*LC_\)/#\1/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
fi

# Generate the initial "locate" DB...
if sudo test -x /etc/cron.daily/mlocate; then
    sudo /etc/cron.daily/mlocate
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


echo "provision.sh: Running project-specific actions..."

# IUS gives us recent (but stable) packages...
sudo yum -q -y --nogpgcheck install "https://centos${CENTOS_RELEASE}.iuscommunity.org/ius-release.rpm" || true
sudo rpm --import "/etc/pki/rpm-gpg/IUS-COMMUNITY-GPG-KEY"

# Install extra packages needed for the project...
sudo yum -q -y install \
    git gcc gcc-c++ automake

# Additional project-specific customizations...
# [...]


echo "provision.sh: Done!"


# vim: set expandtab ts=4 sw=4:
