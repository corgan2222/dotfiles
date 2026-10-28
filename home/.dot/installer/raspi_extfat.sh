#!/bin/bash
# installer: exFAT and NTFS tools (exfatprogs, ntfs-3g, lsof)
# systems: debian
# exFAT itself is in the kernel (5.7+), exfatprogs adds mkfs/fsck; ntfs-3g mounts NTFS read-write;
# lsof shows what keeps a drive busy before unmounting.
# category: raspberry
# check: /usr/sbin/mkfs.exfat|/sbin/mkfs.exfat
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_pkg_install exfatprogs ntfs-3g lsof || dot_die "could not install exfatprogs ntfs-3g lsof"
