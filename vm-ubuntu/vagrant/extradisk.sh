#!/bin/bash -eu
#
# Initialize an extra data disk for Ubuntu VMs (vagrant shell provisioner).
#


if [[ "$(id -u)" != "$(id -u vagrant)" ]]; then
    echo "The provisioning script must be run as the \"vagrant\" user!" >&2
    exit 1
fi


readonly FS_MOUNT_POINT="${1:-/srv/data}"
readonly FS_LABEL="extra-disk"
readonly FS_TYPE="ext4"  # ..."ext4" or "xfs".


if egrep -q "^LABEL=${FS_LABEL}\s" /etc/fstab; then  # ...this script already ran.
    exit 0
fi


echo "extradisk.sh: Setting up an extra data disk: ${FS_MOUNT_POINT}"

# The data disk is on the highest port of the controller, so it should appear as the last disk...
readonly DISK_DEVICE=$(sudo parted /dev/sda print devices | egrep '^/dev/sd[b-z]\s' | cut -f1 -d' ' | sort | tail -1)

if ls "${DISK_DEVICE}"? >/dev/null 2>&1; then
    echo "The data disk device '${DISK_DEVICE}' is already partitioned!" >&2
    exit 1
fi

if ! sudo file -s /dev/sdc | egrep -q "^${DISK_DEVICE}: data$"; then
    echo "The data disk device '${DISK_DEVICE}' is already initialized!" >&2
    exit 1
fi

sudo parted -s "${DISK_DEVICE}" mklabel msdos
sudo parted -s "${DISK_DEVICE}" mkpart primary "${FS_TYPE}" 0% 100%
sudo mkfs.${FS_TYPE} -q -L "${FS_LABEL}" "${DISK_DEVICE}1"

if [[ ! -d "${FS_MOUNT_POINT}" ]]; then
    sudo mkdir -m 0755 -p "${FS_MOUNT_POINT}"
fi

printf "LABEL=${FS_LABEL}\t${FS_MOUNT_POINT}\t${FS_TYPE}\tdefaults\t0 0\n" | sudo tee -a /etc/fstab 2>&1 >/dev/null
sudo mount "${FS_MOUNT_POINT}"


echo "extradisk.sh: Done!"


# vim: set expandtab ts=4 sw=4:
