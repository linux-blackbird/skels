#!/bin/bash

### ADMINISTRATOR


yes | mkfs.vfat -F32 -S 4096 -n BOOT /dev/sdb1

cryptsetup luksFormat /dev/sdb2

cryptsetup luksOpen /dev/sdb2 luks_keys

yes | mkfs.ext4 -L KEYS -b 4096 /dev/mapper/lvm_keys 


### TECHNICAL

yes | mkfs.ext4 -L ROOT -b 4096 /dev/sdb3

yes | mkfs.ext4 -L VARS -b 4096 /dev/sdb4

yes | mkfs.ext4 -L VLOG -b 4096 /dev/sdb5

yes | mkfs.ext4 -L VAUD -b 4096 /dev/sdb6

yes | mkfs.ext4 -L VTMP -b 4096 /dev/sdb7

yes | mkswap /dev/proc/sdb8

yes | mkfs.ext4 -L HOME -b 4096 /dev/sdb9

yes | mkfs.ext4 -L WEB1 -b 4096 /dev/sdb10

yes | mkfs.ext4 -L WEB2 -b 4096 /dev/sdb11



mount /dev/sdb3 /mnt/

mkdir /mnt/boot  && mount -o uid=0,gid=0,fmask=0077,dmask=0077 /dev/sdb1 /mnt/boot

mkdir /mnt/var && mount -o defaults,rw,nosuid,nodev,noexec,relatime /dev/sdb4 /mnt/var

mkdir /mnt/var/log && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb5 /mnt/var/log

mkdir /mnt/var/log/audit && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb6 /mnt/var/log/audit

mkdir /mnt/var/tmp && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb7 /mnt/var/tmp

swapon /dev/sdb8

mkdir /mnt/home && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb9  /mnt/home 

mkdir /mnt/srv/ /mnt/srv/http /mnt/srv/http/public  && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb10 /mnt/srv/http/public

mkdir /mnt/srv/http/intern  && mount -o rw,nosuid,nodev,noexec,relatime /dev/sdb11 /mnt/srv/http/intern



pacstrap /mnt/ linux-hardened linux-firmware mkinitcpio amd-ucode base base-devel neovim git luksmeta clevis mkinitcpio-nfs-utils openssh polkit less firewalld tang apparmor libpwquality rsync reflector nftables tuned tuned-ppd irqbalance

genfstab -U /mnt/ > /mnt/etc/fstab 

cp /etc/systemd/network/* /mnt/etc/systemd/network/

echo 'tmpfs     /tmp        tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/etc/fstab

echo 'tmpfs     /dev/shm    tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/etc/fstab

pacman -Syy git --noconfirm

git clone https://github.com/linux-blackbird/conf

cp -fr conf/bbconfig/vhosted/* /mnt/ 

arch-chroot /mnt

echo blackroz > /etc/hostname

ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

hwclock --systohc 

timedatectl set-ntp true

printf "en_US.UTF-8 UTF-8\nen_US ISO-8859-1" >> /etc/locale.gen

locale-gen && locale > /etc/locale.conf

sed -i '1s/.*/'LANG=en_US.UTF-8'/' /etc/locale.conf

echo 'EDITOR="/usr/bin/nvim"' >> /etc/environment



### ADMINISTRATOR

useradd -m lektor

chown -R lektor:lektor /home/lektor

passwd lektor

mkdir /opt/cockpit

useradd -d /opt/cockpit h3x0r

usermod -a -G wheel h3x0r

echo 'h3x0r ALL=(ALL:ALL) ALL' > /etc/sudoers.d/00_lektor

chown h3x0r:h3x0r /opt/cockpit

passwd h3x0r

passwd -l root

su h3x0r

git clone https://aur.archlinux.org/mkinitcpio-clevis-hook /tmp/clevis

makepkg -sric --dir /tmp/clevis --noconfirm

gpg --recv-keys 2BBBD30FAAB29B3253BCFBA6F6947DAB68E7B931

git clone https://aur.archlinux.org/aide.git /tmp/aide

makepkg -sric --dir /tmp/aide --noconfirm

exit


### TECHNICAL


systemctl enable systemd-networkd.socket

systemctl enable systemd-resolved

echo "root=/dev/sdb3" > /etc/cmdline.d/01-boot.conf

echo "data UUID=$(blkid -s UUID -o value /dev/nvme0n1p4) none" >> /etc/crypttab

echo "intel_iommu=on i915.fastboot=1" >> /etc/cmdline.d/02-mods.conf

mv /boot/amd-ucode.img /boot/vmlinuz-linux-hardened /boot/kernel

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

modprobe -r dccp 2> /dev/null && rmmod dccp 2>/dev/null

modprobe -r rds 2> /dev/null && rmmod rds 2> /dev/null

modprobe -r sctp 2> /dev/null && rmmod sctp 2> /dev/null

mkinitcpio -P

exit

umount -R /mnt

reboot

ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

pacman -S libpam-google-authenticator qrencode

su lektor

google-authenticator