#!/bin/sh
#
# Image generation script for DE1 SoC
#
# Script shall be run as root.

VERSION=$(date '+%Y.%m.%d')
NAME="hsd-de1-soc_${VERSION}"
IMAGE="${NAME}.img"
MD5="${NAME}.md5"
SIZE=$((1024*1024*320))
MNT=mnt
PRELOADER=preloader/preloader-mkpimage.bin
UBOOT=u-boot/u-boot.img
UBOOTSCRIPTMAKEFILE=u-boot-script/Makefile
UBOOTSCRIPT=u-boot-script/u-boot.scr
FPGA=fpga/soc_system.rbf
DEVICETREE=dtb/socfpga_cyclone5_de1soc.dtb
ROOTFS_FILE=rootfs.tar.gz
ROOTFS_DIR=rootfs

echo Create empty image
[ -f  "$IMAGE" ] && rm "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=512 count=$(($SIZE/512)) > /dev/null 2>&1

echo Create partition table
#fdisk -u -S 32 -H 16 "$IMAGE" <<EOFFDISK > /dev/null 2>&1
fdisk "$IMAGE" <<EOFFDISK > /dev/null 2>&1
n
p
3

4095
t
a2
n
p
1

+16M
t
1
b
n
p
2


t
2
83
w
EOFFDISK

echo Mount image
DEVICE=$(losetup -f -P --show "$IMAGE")
echo Using $DEVICE
ls -l /dev/loop*
[ -d $MNT ] || mkdir $MNT

echo Setup preloader partition
PARTITION="${DEVICE}p3"
if [ -b "$PARTITION" ]; then
	if [ -f "$PRELOADER" ]; then
		dd if="$PRELOADER" of="$PARTITION" > /dev/null 2>&1
	else
		echo "$PRELOADER" does not exist
	fi
else
	echo "$PARTITION" does not exist
fi

echo Setup bootloader partition
PARTITION="${DEVICE}p1"
if [ -b "$PARTITION" ]; then
	mkfs.vfat "$PARTITION" > /dev/null 2>&1
	mount "$PARTITION" "$MNT"
	if [ -f "$UBOOT" ]; then
		cp "$UBOOT" "$MNT"/u-boot.img
	else
		echo "$UBOOT" does not exist
	fi
	if [ -f "$UBOOTSCRIPTMAKEFILE" ]; then
		make -C $(dirname "$UBOOTSCRIPTMAKEFILE")
	fi
	if [ -f "$UBOOTSCRIPT" ]; then
		cp "$UBOOTSCRIPT" "$MNT"/u-boot.scr
	else
		echo "$UBOOTSCRIPT" does not exist
	fi
	if [ -f "$FPGA" ]; then
		cp "$FPGA" "$MNT"/socfpga.rbf
	else
		echo "$FPGA" does not exist
	fi
	if [ -f "$DEVICETREE" ]; then
		cp "$DEVICETREE" "$MNT"/socfpga.dtb
	else
		echo "$DEVICETREE" does not exist
	fi
	ls -l "$MNT"
	umount "$MNT"
else
	echo "$PARTITION" does not exist
fi

echo Setup Linux partition
PARTITION="${DEVICE}p2"
if [ -b "$PARTITION" ]; then
	mkfs.ext4 -O ^huge_file "$PARTITION" > /dev/null 2>&1
	mount "$PARTITION" "$MNT"
	if [ -d "$ROOTFS_DIR" ]; then
		cp -r --preserve=all "$ROOTFS_DIR"/* "$MNT"
	elif [ -f "$ROOTFS_FILE" ]; then
		tar zxf "$ROOTFS_FILE" --xattrs --xattrs-include='*' -C "$MNT" > /dev/null 2>&1
	else
		echo "$ROOTFS_FILE" does not exist
	fi
	echo $VERSION > "$MNT"/etc/hsd
	ls -l "$MNT"
	umount "$MNT"
else
	echo "$PARTITION" does not exist
fi

echo Umount image
losetup -d $DEVICE

echo Compress image
gzip -fk $IMAGE

echo Calculate MD5
md5sum ${NAME}.* > ${NAME}.md5

exit 0
