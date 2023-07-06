#!/bin/sh
qemu-system-x86_64 -smp 2 -m 4096 -device virtio-vga-gl  -display gtk,gl=on -net nic,netdev=net0 -netdev user,id=net0  -accel kvm  -drive file=/root/xg64.img,format=raw 2>&1 | tee /tmp/qemu.log
