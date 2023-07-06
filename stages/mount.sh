#!/bin/bash
devn=$(losetup -f -P --show /root/xg64.img)
ppath=/mnt/bak/xiange/2023.6

echo $devn

mount ${devn}p1 /mnt/image 
mount --bind  $ppath/sources /mnt/image/var/xiange/sources
mount --bind $ppath/packages-x86_64 /mnt/image/var/xiange/packages
mount --bind /var/xiange/xglibs /mnt/image/var/xiange/xglibs
gpkg -chroot /mnt/image


umount /mnt/image/var/xiange/sources
umount /mnt/image/var/xiange/xglibs
umount /mnt/image/var/xiange/packages
gpkg -unchroot /mnt/image
umount /mnt/image
losetup -d $devn
