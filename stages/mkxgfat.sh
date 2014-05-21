#!/bin/sh

#
# make a Xiange Linux bootable vfat usb disk
#


NORMAL="\\033[0;39m" # Standard console grey
SUCCESS="\\033[1;32m" # Success is green
WARNING="\\033[1;33m" # Warnings are yellow
FAILURE="\\033[1;31m" # Failures are red
INFO="\\033[1;36m" # Information is light cyan
BRACKET="\\033[1;34m" # Brackets are blue

#show info in cyan color, $1 is information.
showinfo()
{
	echo -e  $INFO"$1"$NORMAL
}

#show OK message in green color, $1 is information.
showOK()
{
	echo -e $SUCCESS"$1"$NORMAL
}

#show OK message in green color, $1 is information.
showFailed()
{
	echo -e $FAILURE"$1"$NORMAL
}

#check return code. show $1 if error.
err_check()
{
	if [ $? != 0 ]; then
		echo -e $FAILURE"$1"
		exit 1
	fi
}

# $1 is output file
xg_mkgrubcfg_head()
{
	cat > $1 << EOF
#
# DO NOT EDIT THIS FILE
#
# It is automatically generated by Xiange install script 
# Lihui Zhang <swordhuihui@gmail.com>
# 2014.05.14

set timeout=5


EOF
}

# $1 is arch. $2 is kerver-version. $3 is device index. $4 is UUID
# $5 is output file $6 is initrd-file 
# $7 will be added to kernel command line 
xg_mkgrubcfg_item()
{
	echo -e "menuentry 'Xiange Linux $1 $2' {" >> $5
	echo -e "\tinsmod gzio" >> $5
	echo -e "\tinsmod part_msdos" >> $5
	echo -e "\tinsmod ext2" >> $5
	echo -e "\tset root='hd0,msdos$3'" >> $5
	echo -e "\techo 'Loading Xiange Linux $1 $2...'" >> $5
	echo -e "\tlinux /boot/vmlinuz-$2 root=UUID=$4 $7 rw quiet" >> $5
	if [ -n "$6" ]; then
		echo -e "\tinitrd $6" >> $5
	fi
	echo "}" >> $5
}


#
# deal with kernel, $1 is version
#
xg_do_kernel()
{
	#copy kernel
	cp -a $oldroot/boot/vmlinuz-$1 $newroot/boot
	err_check "copy $oldroot/boot/vmlinuz-$1 faile.d"

	cp -a $oldroot/boot/config-$1 $newroot/boot
	err_check "copy $oldroot/boot/config-$1 faile.d"

	#get initrams
	rm -rf /tmp/xgmnt/init
	mkdir /tmp/xgmnt/init
	cd /tmp/xgmnt/init
	err_check "enter /tmp/xgmnt/init failed."

	gunzip -c $oldroot/boot/initramfs-1.0.img.gz | cpio -i 
	err_check "unzip $oldroot/boot/initramfs-1.0.img.gz failed."

	XGLIST="/lib/libdevmapper.so.1.02 
		/lib/libc.so.6
		/lib/libc-2.19.so 
		/lib/libpthread.so.0 
		/lib/libpthread-2.19.so 
		/lib/ld-2.19.so 
		/lib/ld-linux-x86-64.so.2 
		/sbin/dmsetup
		/lib/modules/$1/kernel/drivers/block/loop.ko
		/lib/modules/$1/kernel/fs/squashfs/squashfs.ko
		/lib/modules/$1/kernel/drivers/md/dm-snapshot.ko
		/lib/modules/$1/kernel/drivers/md/dm-mod.ko"
		
	ln -sv lib /tmp/xgmnt/init/lib64
	err_check "create lib64 failed."
	mkdir -p /tmp/xgmnt/init/root
	err_check "create root failed."

	#copy file in list
	for i in $XGLIST;
	do
		basen=$(dirname $i)
		mkdir -p /tmp/xgmnt/init$basen
		showinfo "copying $oldroot$i..."
		cp -a $oldroot$i /tmp/xgmnt/init$basen/
		err_check "cp $oldroot$i failed."
	done

	
	#init
	cp /var/xiange/xglibs/stages/init /tmp/xgmnt/init/init
	err_check "copy init failed."

	#make depfiles
	mount -t proc none /tmp/xgmnt/init/proc
	mount -t sysfs none /tmp/xgmnt/init/sys
	mount --bind /dev /tmp/xgmnt/init/dev
	chroot /tmp/xgmnt/init /sbin/depmod $1
	err_check "dempode failed."

	#check dmsetup
	chroot /tmp/xgmnt/init /sbin/dmsetup --help 
	err_check "dempode failed."

	#sleep 1
	umount /tmp/xgmnt/init/dev
	err_check "umount dev failed."
	umount /tmp/xgmnt/init/sys
	err_check "umount sys failed."
	umount /tmp/xgmnt/init/proc
	err_check "umount proc failed."

	#generate new initramfs
	find | cpio -o -H newc > $newroot/boot/initramfs-$1.img
	err_check "generate $newroot/boot/initramfs-$1.img failed."
	gzip $newroot/boot/initramfs-$1.img
	err_check "compress $newroot/boot/initramfs-$1.img failed."

	showinfo "$newroot/boot/initramfs-$1.img.gz is ready."

	initrdf=/boot/initramfs-$1.img.gz

	#boot.cfg
	xg_mkgrubcfg_item "$XGB_ARCH" "$1" "$devindex" "$newid" "$outputf" "$initrdf"
	xg_mkgrubcfg_item "$XGB_ARCH (Safemode)" "$1" "$devindex" "$newid" "$outputf" "$initrdf" "safemode"

}

xg_mksquash()
{
	if [ -f "/root/xg64.img" ]; then
		ls -l /root/xg64.img
	else
		showFailed "No Xg64.img found."
		exit 1
	fi
	
	showinfo "copying ..."
	rm -rf /tmp/squashroot
	mkdir -p /tmp/squashroot
	cp -a /root/xg64.img /tmp/squashroot/
	err_check "copy failed."
	
	showinfo "making squash fs.."
	
	cd /tmp
	rm -f xiange-sqroot
	mksquashfs squashroot xiange-sqroot
	err_check "make squash fs failed."
	
	rm -rf squashroot
	err_check "rm temperory file failed."
}

xg_prepare()
{
	mkdir -p /tmp/xgmnt/0
	mkdir -p /tmp/xgmnt/1
	mkdir -p /tmp/xgmnt/2
	
	#load modules
	modprobe loop
	err_check "load loop failed."
	modprobe squashfs
	err_check "load squashfs failed."
}

xg_mount_squash()
{
	mount xiange-sqroot /tmp/xgmnt/0 -o loop 
	err_check "mount xiange-sqroot to /tmp/xgmnt/0 failed."
	
	showinfo "mount xiange root.."
	losetup -P /dev/loop2 /tmp/xgmnt/0/xg64.img
	err_check "setup xg64 to /dev/loop2 faled."

	showinfo "mounting new root..."
	mount /dev/loop1p1 /tmp/xgmnt/1
	err_check "mount loop1p1 failed."
	
	mount /dev/loop2p1 /tmp/xgmnt/2
	err_check "mount to /mnt/xgmnt/2 faled."
}

xg_mkddimg()
{
	imgfile="/root/xg_sqh.img"
	disksize=4000000000
	blocks=$(($disksize/512))
	
	showinfo "create image file $imgfile, size $(($disksize/1000000000)) GB.."
	dd if=/dev/zero of=$imgfile count=$blocks
	err_check "failed."
	
	showinfo "mount to a image.."
	losetup -P /dev/loop1 $imgfile
	err_check "setup $imgfile to /dev/loop1 faled."
	
	showinfo "create partitions..."
	cfdisk /dev/loop1
	err_check "create partition failed."
	
	showinfo "formating..."
	mkfs.ext4 -v /dev/loop1p1
	err_check "format /dev/loop1p1 failed."
	
	
	showinfo "mounting..."
	mount /dev/loop1p1 /tmp/xgmnt/1
	err_check "mount loop1p1 failed."
	
	showinfo "installing grub2..."
	grub-install --modules=part_msdos --root-directory=/tmp/xgmnt/1 /dev/loop1
	err_check "install grub failed."

	showinfo "unmount /tmp/xgmnt/1..."
	mount /tmp/xgmnt/1
	err_check "unmount grub failed."
}


#
# init here
#

xg_prepare
xg_mount_squash


oldroot=/tmp/xgmnt/2
newroot=/tmp/xgmnt/1

outputf=$newroot/boot/grub/grub.cfg
mkdir -p /boot/grub

gpkg -info > /tmp/gpkginfo
. /tmp/gpkginfo

devname="/dev/loop1p1"
newid=$(blkid -o value $devname 2>/dev/null | head -n 1)
devindex=1

if [ -z "$newid" ]; then
	showFailed "UUID check failed."
	exit 2
fi

if [ -z "$XGB_ARCH" ]; then
	showFailed "arch check failed."
	exit 4
fi


xg_mkgrubcfg_head $outputf


showinfo "checking kernel ..."
for i in $oldroot/boot/vmlinuz-*; 
do
	i=$(basename $i)
	kernelv=${i#vmlinuz-}
	showinfo found $i, kerver version: $kernelv
	xg_do_kernel $kernelv
done

#squshfs.img
showinfo "copy squashfs image.."
mv /tmp/xiange-sqroot $newroot
err_check "copy /tmp/xiange-sqroot to $newroot failed."

#cow.img (1G)
showinfo "creating cow image.."
dd if=/dev/zero of=$newroot/cow.out count=$((2*1024*1500))
err_check "create $newroot/cow.out failed."

#unmount newroot
showinfo "unmounting $newroot..."
umount $newroot
err_check "unmount $newroot failed."

showinfo "unmounting $oldroot..."
umount $oldroot
err_check "unmount $oldroot failed."

losetup -d /dev/loop1
err_check "remove /dev/loop1 failed."
losetup -d /dev/loop2
err_check "remove /dev/loop2 failed."

showinfo "unmounting /tmp/xgmnt/0.."
umount /tmp/xgmnt/0
err_check "unmount /tmp/xgmnt/0 failed."

rm -rf /tmp/xgmnt

showOK "done"

