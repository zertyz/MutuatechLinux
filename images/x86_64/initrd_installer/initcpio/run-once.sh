#!/usr/bin/bash

# Settings
ARCH=`uname -m`
IMAGE_URL="http://mutuatech.com/MutuatechLinux/images/$ARCH/mutuatechlinux-general-x86_64.img.xz"
IMAGE_ROOT_PARTITION_N=3


setup_network() {

    ETH=`ifconfig -a -s | grep '^e' | sed 's| .*||'`
    WLAN=`ifconfig -a -s | grep '^w' | sed 's| .*||'`

    ifconfig ${ETH} up
    sleep 1
    NETDEV=${ETH}

    for i in {1..2}; do
	# wired network until proven otherwise
	ifconfig ${ETH} up
	sleep 1
	NETDEV=${ETH}

	if [ `cat /sys/class/net/${ETH}/carrier_up_count || echo 0` -eq 0 ]; then
		# try wireless network if the cable is unplugged (if wirless does not work, it is probably due to the time it takes to detect the wireless hardware: a sleep may help)
		if ifconfig ${WLAN} up; then
			wpa_supplicant -B -c /etc/wpa_supplicant/wpa_supplicant.conf -i ${WLAN}
			sleep 3
			ifconfig ${ETH} down   # try to save a little power
			NETDEV=${WLAN}
		fi
	fi
	echo "### `date`: starting network for interface ${NETDEV} -- eth is ${ETH}; wlan is ${WLAN}"
	# get the IP
	dhclient -pf /run/dhclient.pid -lf /run/dhclient.leases ${NETDEV} || dhcpcd -4p ${{NETDEV} || continue
	# time set & network test
	sleep 3
	ping -c1 -W1 1.1.1.1 &>/dev/null && return 0 || sleep 16
	pkill dhclient
	pkill dhcpcd
    done
    echo  ":::::::::: FAILED at setting up the network ::::::::::"
    return 1
}

# sets the variables `root_disk_dev` and `rootfs_dev`
determine_root_device() {
    root_arg=$(sed -n 's/.*\broot=\([^ ]*\).*/\1/p' /proc/cmdline)

    case "$root_arg" in
      UUID=*|LABEL=*|PARTUUID=*|PARTLABEL=*)
        rootfs_dev=$(blkid -t "$root_arg" -o device) ;;
      /dev/*)
        rootfs_dev=$(readlink -f -- "$root_arg") ;;
      "")
        # no root arg? let's pretend it is already mounted to /new_root
	# (most probably we must set rootfs_dev to empty)
        rootfs_dev=$(findmnt -no SOURCE /new_root) ;;
      *)
        rootfs_dev=""  # e.g. ZFS=…/ nfs:… not supported
    esac

    root_disk_dev=$(lsblk -no PATH -p -s "$rootfs_dev" | sort | head -n1)

    # check if we really could determine the root disk dev
    [[ ${root_disk_dev-} =~ ^/dev/ ]] || {
	echo ":::::::::: FAILED at determining what was the root disk device. The kernel cmdline was '`cat /proc/cmdline`' ::::::::::"
        return 1
    }
}

install_image() {

    determine_root_device &&

    echo ":::::::::: Downloading and installing full HD image to ${root_disk_dev} ::::::::::" &&

    wget -O - -c "${IMAGE_URL}" |
      xz -T1 -dcvvvv |
      dd of=${root_disk_dev} bs=$((64*1024*1024)) status=progress &&

    echo ":::::::::: Growing the rootfs partition to take all the remaining device space in ${root_disk_dev} ::::::::::" &&
    growpart "$root_disk_dev" ${IMAGE_ROOT_PARTITION_N} &&
    echo "::::::::::     refreshing the kernel's partition table ::::::::::" &&
    partprobe "$root_disk_dev" || return 1

    # determine the device for the root partition
    if [[ $root_disk_dev =~ [0-9]$ ]]; then
        root_fs_dev="${root_disk_dev}p${IMAGE_ROOT_PARTITION_N}"
    else
        root_fs_dev="${root_disk_dev}${IMAGE_ROOT_PARTITION_N}"
    fi
    # wait a bit for the device to appear
    for i in {1..10}; do [[ -b "$root_fs_dev" ]] && break; sleep 1; done
    [[ -b "$root_fs_dev" ]] || {
	echo ":::::::::: FAILED at accessing the root partition device at '${root_fs_dev}'. The root disk device was '${root_disk_dev}' ::::::::::"
        return 1
    }

    echo ":::::::::: Resizing the root filesystem to use the whole partition ::::::::::" &&
    tmp="$(mktemp -d)" &&
    mount "$root_fs_dev" "$tmp" &&
    btrfs filesystem resize max "$tmp" &&
    umount "$tmp" &&
    rmdir "$tmp" || {
        echo ":::::::::: FAILED resizing the root filesystem '${root_fs_dev}' (attempted to be mounted at '${tmp}') ::::::::::"
        return 1
    }
    
}

setup_network &&
install_image &&
exit 0 || exit 1
