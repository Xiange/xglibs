#!/bin/sh

#
# Xiange installation script : stage0 things
#
#	Copyright (C) Lihui Zhang <swordhuihui@gmail.com>
#	2014.05.27
#	Licence: GPL V2
#
#	this script can be only called in chroot enviroment after stage0 installed.

scriptpath=/var/xiange/xglibs/stages
. $scriptpath/baseio.sh

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
xg_mkgrubcfg_item()
{
	echo -e "menuentry 'Xiange Linux $1 $2' {" >> $5
	echo -e "\tinsmod gzio" >> $5
	echo -e "\tinsmod part_msdos" >> $5
	echo -e "\tinsmod ext2" >> $5
	echo -e "\tset root='hd0,msdos$3'" >> $5
	echo -e "\techo 'Loading Xiange Linux $1 $2...'" >> $5
	echo -e "\tlinux /boot/vmlinuz-$2 root=UUID=$4 rw quiet" >> $5
	if [ -n "$6" ]; then
		echo -e "\tinitrd $6" >> $5
	fi
	echo "}" >> $5
}

#change blkid
devname=$(mount | grep "on / " | grep -o "^[^ \t]*")
newid=$(blkid -o value $devname 2>/dev/null | head -n 1)
devnameraw=$(basename $devname)
devnameraw2=${devnameraw%[0-9]}
devindex=${devnameraw#$devnameraw2}

outputf=/boot/grub/grub.cfg
mkdir -p /boot/grub

gpkg -info > /tmp/gpkginfo
. /tmp/gpkginfo

initrdf=$(ls /boot/initramfs*)

echo "devname: $devname, UUID: $newid, Index: $devindex"
echo "Arch: $XGB_ARCH"
echo "initramfs: $initrdf"

if [ -z "$newid" ]; then
	showFailed "UUID check failed."
	exit 2
fi

if [ -z "$devindex" ]; then
	showFailed "devindex check failed."
	exit 3
fi

if [ -z "$XGB_ARCH" ]; then
	showFailed "arch check failed."
	exit 4
fi


xg_mkgrubcfg_head $outputf



echo "checking kernels.."


for i in /boot/vmlinuz-*; 
do
	i=$(basename $i)
	kernelv=${i#vmlinuz-}
	echo found $i, kerver version: $kernelv
	xg_mkgrubcfg_item "$XGB_ARCH" "$kernelv" "$devindex" "$newid" "$outputf" "$initrdf"
done

#showinfo "change UUID to $newid (dev $devname)..."
#sed -i "s@root=UUID=[^ \t]*@root=UUID=$newid@g" /boot/grub/grub.cfg
#err_check "change UUID to $newid failed."

showinfo "enable network manager.."
systemctl enable NetworkManager
err_check "enable network manager failed."

#enable sshd
showinfo "enable sshd manager.."
systemctl enable sshd
err_check "enable sshd failed"

#enable smartd
showinfo "enable smartd manager.."
systemctl enable smartd
err_check "enable sshd failed"


showOK "all done. ready for stage2"
showinfo "If you want install stage2, please remove vim with gpkg -D vim."

