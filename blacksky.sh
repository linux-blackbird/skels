#!/bin/bash

### ADMINISTRATOR

cryptsetup luksFormat /dev/nvme0n1p2

cryptsetup luksFormat /dev/nvme0n1p3

cryptsetup luksFormat /dev/nvme0n1p4

cryptsetup luksOpen /dev/nvme0n1p2 lvm_keys

yes | mkfs.ext4 -L KEYS /dev/mapper/lvm_keys 

cryptsetup luksOpen /dev/nvme0n1p3 lvm_root

cryptsetup luksOpen /dev/nvme0n1p4 lvm_data


### TECHNICAL

pvcreate /dev/mapper/lvm_root

vgcreate proc /dev/mapper/lvm_root

yes | lvcreate -L 10G proc -n root

yes | lvcreate -L 5G proc -n vars

yes | lvcreate -L 1.5G proc -n vtmp

yes | lvcreate -L 5G proc -n vlog

yes | lvcreate -L 2.5G proc -n vaud

yes | lvcreate -l100%FREE proc -n swap

pvcreate /dev/mapper/lvm_data

vgcreate data /dev/mapper/lvm_data

yes | lvcreate -L 5G data -n home

yes | lvcreate -l100%FREE data -n host

yes | mkfs.vfat -F32 -S 4096 -n BOOT /dev/nvme0n1p1

yes | mkfs.ext4 -b 4096 /dev/data/home

mkfs.xfs -fs size=4096 /dev/data/host

yes | mkfs.ext4 -b 4096 /dev/proc/root

yes | mkfs.ext4 -b 4096 /dev/proc/vars

yes | mkfs.ext4 -b 4096 /dev/proc/vtmp

yes | mkfs.ext4 -b 4096 /dev/proc/vlog

yes | mkfs.ext4 -b 4096 /dev/proc/vaud

yes | mkswap /dev/proc/swap

mount /dev/proc/root /mnt/

mkdir /mnt/boot && mount -o uid=0,gid=0,fmask=0077,dmask=0077 /dev/nvme0n1p1 /mnt/boot

mkdir /mnt/var && mount -o defaults,rw,nosuid,nodev,noexec,relatime /dev/proc/vars /mnt/var

mkdir /mnt/var/tmp && mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vtmp /mnt/var/tmp

mkdir /mnt/var/log && mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vlog /mnt/var/log

mkdir /mnt/var/log/audit && mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vaud /mnt/var/log/audit

mkdir /mnt/home && mount -o rw,nosuid,nodev,noexec,relatime /dev/data/home /mnt/home 

mkdir /mnt/var/lib /mnt/var/lib/libvirt /mnt/var/lib/libvirt/images && mount /dev/data/host /mnt/var/lib/libvirt/images 

swapon /dev/proc/swap

pacstrap /mnt/ linux-hardened linux-firmware mkinitcpio intel-ucode xfsprogs lvm2 base base-devel neovim git luksmeta clevis mkinitcpio-nfs-utils openssh polkit less firewalld tang apparmor libpwquality rsync qemu-base libvirt openbsd-netcat reflector nftables tuned tuned-ppd irqbalance

genfstab -U /mnt/ > /mnt/etc/fstab 

cp /etc/systemd/network/* /mnt/etc/systemd/network/

echo 'tmpfs     /tmp        tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/etc/fstab

echo 'tmpfs     /dev/shm    tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/etc/fstab

pacman -Syy git --noconfirm

git clone https://github.com/linux-blackbird/conf

cp -fr conf/bbconfig/vhosted/* /mnt/ 

arch-chroot /mnt

echo blacksky > /etc/hostname

ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

hwclock --systohc 

timedatectl set-ntp true

printf "en_US.UTF-8 UTF-8\nen_US ISO-8859-1" >> /etc/locale.gen

locale-gen && locale > /etc/locale.conf

sed -i '1s/.*/LANG=en_US.UTF-8'/' /etc/locale.conf

echo 'EDITOR="/usr/bin/nvim"' >> /etc/environment



### ADMINISTRATOR

useradd -m lektor

chown -R lektor:lektor /home/lektor

passwd lektor

mkdir /opt/cockpit

useradd -d /opt/cockpit nepster

usermod -a -G wheel nepster

echo 'nepster ALL=(ALL:ALL) ALL' > /etc/sudoers.d/00_lektor

chown nepster:nepster /opt/cockpit

passwd nepster

passwd -l root

useradd -d /opt/var/lib/livirt/images joyboy

setfacl -Rm u:joyboy:rw /var/lib/libvirt/images

passwd joyboy

su nepster

git clone https://aur.archlinux.org/mkinitcpio-clevis-hook /tmp/clevis

makepkg -sric --dir /tmp/clevis --noconfirm

gpg --recv-keys 2BBBD30FAAB29B3253BCFBA6F6947DAB68E7B931

git clone https://aur.archlinux.org/aide.git /tmp/aide

makepkg -sric --dir /tmp/aide --noconfirm

exit

usermod -a -G libvirt joyboy

usermod -a -G libvirt nepster


### TECHNICAL


systemctl enable systemd-networkd.socket

systemctl enable systemd-resolved

echo "cryptdevice=UUID=$(blkid -s UUID -o value /dev/nvme0n1p3):crypto root=/dev/proc/root" > /etc/cmdline.d/01-boot.conf

echo "data UUID=$(blkid -s UUID -o value /dev/nvme0n1p4) none" >> /etc/crypttab

echo "intel_iommu=on i915.fastboot=1" >> /etc/cmdline.d/02-mods.conf

mv /boot/intel-ucode.img /boot/vmlinuz-linux-hardened /boot/kernel

rm /boot/initramfs-*

bootctl --path=/boot/ install

touch /etc/vconsole.conf

systemctl enable firewalld

systemctl enable sshd


systemctl enable tangd.socket

systemctl enable apparmor.service


cp /etc/pacman.d/mirrorlist /etc/pacman.d/backupmirror 

systemctl enable tuned-ppd

systemctl enable irqbalance.service

systemctl enable libvirtd.socket

chown root:root /etc/crontab && chmod og-rwx /etc/crontab

chown root:root /etc/cron.hourly/ && chmod og-rwx /etc/cron.hourly/

chown root:root /etc/cron.daily/ && chmod og-rwx /etc/cron.daily/

chown root:root /etc/cron.weekly/ && chmod og-rwx /etc/cron.weekly/

chown root:root /etc/cron.monthly/ && chmod og-rwx /etc/cron.monthly/

chown root:root /etc/cron.d/ && chmod og-rwx /etc/cron.d

modprobe -r hfs 2> /dev/null && rmmod hfs 2> /dev/null 

modprobe -r hfsplus 2> /dev/null && rmmod hfsplus 2> /dev/null

modprobe -r jffs2 2> /dev/null && rmmod jffs2 2> /dev/null

modprobe -r squashfs 2> /dev/null && rmmod squashfs 2> /dev/null


modprobe -r udf 2> /dev/null && rmmod udf 2> /dev/null


## disable usb-storage file system module from kernel
## modprobe -r usb-storage 2>/dev/null; rmmod usb-storage 2>/dev/null

modprobe -r 9p 2> /dev/null && rmmod 9p 2> /dev/null

modprobe -r affs 2> /dev/null && rmmod affs 2> /dev/null

modprobe -r afs 2> /dev/null && rmmod afs 2> /dev/null

modprobe -r fuse 2> /dev/null && rmmod fuse 2> /dev/null

systemctl mask nfs-server.service

modprobe -r dccp 2> /dev/null && rmmod dccp 2>/dev/null

modprobe -r rds 2> /dev/null && rmmod rds 2> /dev/null

modprobe -r sctp 2> /dev/null && rmmod sctp 2> /dev/null

mkinitcpio -P

exit

umount -R /mnt

reboot