#!/bin/bash -eu
#
# Update Fedora VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "updates.sh: Installing system updates..."

# Fix DNS breakage on reprovisioning (sometimes)...
if [ -f /etc/init.d/network ]; then
    sudo systemctl restart network  # ...Fedora <= 28
else
    sudo systemctl restart NetworkManager
fi

# Ensure DNF chooses a decent mirror, otherwise things may be *very* slow...
if ! grep -q "fastestmirror=true" /etc/dnf/dnf.conf; then
    sudo tee -a /etc/dnf/dnf.conf >/dev/null <<< "fastestmirror=true"
fi

sudo rm -f /var/cache/dnf/fastestmirror.cache
sudo dnf -q clean expire-cache
sudo dnf -q makecache

# The image is missing locale files for size, so we filter out spurious warnings about that...
sudo dnf -q -y --setopt=deltarpm=false upgrade \
    | grep -iPv 'warning:.*?\/LC_(MESSAGES|TIME).*?:\s+remove\s+failed:\s+' || echo "The system is up to date."

sudo dnf -q -y clean all

readonly LATEST_KERNEL="$(rpm -q kernel-core --qf="%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort --version-sort | tail -1)"

if [[ ! -f "/lib/modules/${LATEST_KERNEL}/misc/vboxsf.ko" ]]; then
    echo "Kernel ${LATEST_KERNEL} needs third-party support for VirtualBox shared folders."
    sudo rcvboxadd quicksetup  # ...rebuild the modules.
fi

echo "updates.sh: Done!"


# vim: set expandtab ts=4 sw=4:
