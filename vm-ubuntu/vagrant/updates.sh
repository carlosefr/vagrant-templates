#!/bin/bash -eu
#
# Update Ubuntu VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


echo "updates.sh: Installing system updates..."


sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y dist-upgrade


echo "updates.sh: Done!"


# vim: set expandtab ts=4 sw=4:
