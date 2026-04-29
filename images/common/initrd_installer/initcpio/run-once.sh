#!/usr/bin/bash

# Settings
ARCH=`uname -m`
IMAGE_URL="http://mutuatech.com/MutuatechLinux/images/$ARCH/mutuatechlinux-general-${ARCH}.img.xz"
IMAGE_ROOT_PARTITION_N=2
IMAGE_SWAP_PARTITION_N=3
[[ -f /root/initcpio/image-install.env ]] && . /root/initcpio/image-install.env


setup_network() {

    # prepare dhcpcd directories
    mkdir -p /var/lib/dhcpcd

    # wait a little bit for devices to settle
    sleep 2

    # preferred way of determining the network
    ETH=`ifconfig -a -s | grep '^e' | sed 's| .*||'`
    WLAN=`ifconfig -a -s | grep '^w' | sed 's| .*||'`

    # network device not found? be verbose and try several fallback methods
    if [[ ! -n "$ETH"  && ! -n "$WLAN" ]]; then
        echo  "::::::::::     COULDN'T determine the network interfaces using ifconfig. Trying to load common cloud drivers and waiting a little bit for them to settle ::::::::::"
	#modprobe xen_netfront
        #modprobe virtio_pci
        #modprobe virtio_net
        #modprobe virtio_scsi
        #modprobe virtio_ring
        #modprobe virtio
        #modprobe ena
        #modprobe gve
        #modprobe vmxnet3
	sleep 5
	ip link
        ETH=`ifconfig -a -s | grep '^e' | sed 's| .*||'`
        WLAN=`ifconfig -a -s | grep '^w' | sed 's| .*||'`
        if [[ ! -n "$ETH"  && ! -n "$WLAN" ]]; then
            echo  "::::::::::     STILL COULDN'T determine the network interfaces using ifconfig. Please inspect the following 'ifconfig -a' dump ::::::::::"
            ifconfig -a
            echo  "::::::::::     Trying to get the wired network interface through the alternative /sys method ::::::::::"
            for p in /sys/class/net/*; do
                iface=${p##*/};
                [ "$iface" = lo ] && continue                         # skip loopback
                [ -e "$p/device" ] || continue                        # must be backed by hardware
                read type < "$p/type"; [ "$type" -ne 1 ] && continue  # skip ARPHRD_ETHER
                [ -e "$p/wireless" ] && WLAN="$iface" && continue     # wifi
                ETH="$iface"                                          # else ethernet
            done
            if [[ ! -n "$ETH"  && ! -n "$WLAN" ]]; then
                echo  "::::::::::     ALTERNATIVE /sys method also COULDN'T determine the network interfaces :( Please inspect the following 'ls -la /sys/class/net/' dump ::::::::::"
                ls -l /sys/class/net/
                echo  "::::::::::     ... and the 'lsmod' dump ::::::::::"
		lsmod
                echo  "::::::::::     ... and the 'ip -o link show' dump ::::::::::"
		ip -o link show
                echo  "::::::::::     Desperate last attempt using 'ipconfig -t 20 -c dhcp all' ::::::::::"
		ipconfig -t 20 -c dhcp all || /usr/lib/initcpio/ipconfig -t 20 -c dhcp all
                ETH=`ifconfig -a -s | grep '^e' | sed 's| .*||'`
                WLAN=`ifconfig -a -s | grep '^w' | sed 's| .*||'`
            fi
        fi
    fi

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
	dhcpcd "${NETDEV}" || dhclient -pf /run/dhclient.pid -lf /run/dhclient.leases "${NETDEV}" || continue
	# time set & network test
	sleep 3
	echo 'nameserver 8.8.8.8' >/etc/resolv.conf
	ping -c1 -W1 1.1.1.1 &>/dev/null && return 0 || { echo "### `date`: ping test to 1.1.1.1 failed:"; ping -c1 -W1 1.1.1.1; sleep 16; }
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
        rootfs_dev=""  # else not supported
    esac

    root_disk_dev=$(lsblk -no PATH -p -s "$rootfs_dev" | sort | head -n1)

    # check if we really could determine the root disk dev
    [[ ${root_disk_dev-} =~ ^/dev/ ]] || {
	echo ":::::::::: FAILED at determining what was the root disk device. The kernel cmdline was '`cat /proc/cmdline`' ::::::::::"
        return 1
    }
}

partition_device() {
    local disk_dev="$1"
    local partition_n="$2"

    if [[ $disk_dev =~ [0-9]$ ]]; then
        echo "${disk_dev}p${partition_n}"
    else
        echo "${disk_dev}${partition_n}"
    fi
}

wait_for_block_device() {
    local block_dev="$1"

    for i in {1..10}; do
        [[ -b "$block_dev" ]] && return 0
        sleep 1
    done
    return 1
}

move_swap_partition_to_disk_end() {
    local swap_fs_dev swap_type swap_size_bytes swap_size_mib swap_uuid pttype
    local -a mkswap_args

    swap_fs_dev="$(partition_device "$root_disk_dev" "$IMAGE_SWAP_PARTITION_N")"
    [[ -b "$swap_fs_dev" ]] || return 0

    swap_type="$(blkid -s TYPE -o value "$swap_fs_dev" 2>/dev/null || true)"
    [[ "$swap_type" == swap ]] || return 0

    swap_size_bytes="$(lsblk -bno SIZE "$swap_fs_dev" | head -n1)"
    [[ "$swap_size_bytes" =~ ^[0-9]+$ ]] || {
        echo ":::::::::: FAILED at determining the swap partition size for '${swap_fs_dev}' ::::::::::"
        return 1
    }
    swap_size_mib=$(( (swap_size_bytes + 1024 * 1024 - 1) / (1024 * 1024) ))
    swap_uuid="$(blkid -s UUID -o value "$swap_fs_dev" 2>/dev/null || true)"
    pttype="$(blkid -s PTTYPE -o value "$root_disk_dev" 2>/dev/null || true)"

    echo ":::::::::: Recreating swap partition ${swap_fs_dev} at the end of ${root_disk_dev} ::::::::::"
    case "$pttype" in
        gpt)
            sgdisk -e "$root_disk_dev" &&
            sgdisk -d "$IMAGE_SWAP_PARTITION_N" "$root_disk_dev" &&
            sgdisk \
                -n "${IMAGE_SWAP_PARTITION_N}:-${swap_size_mib}M:0" \
                -t "${IMAGE_SWAP_PARTITION_N}:8200" \
                -c "${IMAGE_SWAP_PARTITION_N}:swap" \
                "$root_disk_dev" || return 1
            ;;
        dos)
            parted -s -a optimal -- "$root_disk_dev" \
                rm "$IMAGE_SWAP_PARTITION_N" \
                mkpart primary linux-swap "-${swap_size_mib}MiB" 100% || return 1
            ;;
        *)
            echo ":::::::::: FAILED because partition table type '${pttype}' is unsupported for swap recreation ::::::::::"
            return 1
            ;;
    esac

    echo "::::::::::     refreshing the kernel's partition table ::::::::::" &&
    partprobe "$root_disk_dev" &&
    udevadm settle || return 1

    wait_for_block_device "$swap_fs_dev" || {
        echo ":::::::::: FAILED at accessing the swap partition device at '${swap_fs_dev}' after recreating it ::::::::::"
        return 1
    }

    mkswap_args=(-L swap)
    [[ -n "$swap_uuid" ]] && mkswap_args+=(-U "$swap_uuid")

    echo ":::::::::: Reinitializing swap partition ${swap_fs_dev} ::::::::::" &&
    mkswap "${mkswap_args[@]}" "$swap_fs_dev"
}

install_image() {

    determine_root_device &&

    echo ":::::::::: Downloading and installing full HD image to ${root_disk_dev} ::::::::::" &&

    wget -O - -c "${IMAGE_URL}" |
      xz -T0 -dc |
      dd of=${root_disk_dev} bs=$((64*1024*1024)) status=progress &&

    echo "::::::::::     refreshing the kernel's partition table after writing the image ::::::::::" &&
    partprobe "$root_disk_dev" &&
    udevadm settle &&

    move_swap_partition_to_disk_end || return 1

    echo ":::::::::: Growing the rootfs partition in ${root_disk_dev} ::::::::::" &&
    growpart "$root_disk_dev" ${IMAGE_ROOT_PARTITION_N} &&
    echo "::::::::::     refreshing the kernel's partition table ::::::::::" &&
    partprobe "$root_disk_dev" &&
    udevadm settle || return 1

    # determine the device for the root partition
    root_fs_dev="$(partition_device "$root_disk_dev" "$IMAGE_ROOT_PARTITION_N")"
    # wait a bit for the device to appear
    wait_for_block_device "$root_fs_dev" || {
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
