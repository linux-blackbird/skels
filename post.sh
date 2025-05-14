#!/bin/bash

source /install/userenv
source /install/protcolenv


function config_based() {

    ## create hostname
    echo $HOSTNAME > /etc/hostname

    ## create zoneinfo
    ln -sf /etc/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc

    ## config locales
    printf "$LOCALES1\n $LOCALES2" >> /etc/locale.gen
    locale-gen && locale > /etc/locale.conf
    sed -i '1s/.*/'$LOCALESC'/' /etc/locale.conf

    ## editor environment
    echo 'EDITOR="/usr/bin/nvim"' >> /etc/environment
}


function create_admin() {
    echo 'lektor ALL=(ALL:ALL) ALL' > /etc/sudoers.d/00_lektor
    useradd -m lektor && usermod -aG wheel lektor
    mkdir /home/lektor/{dekstop,download,image,audio,project,share,model,video}
    chown -R lektor:lektor /home/lektor/*
}


function create_share() {
    mkdir /tmp/share 
    useradd -d /tmp/share share && echo "1511" | passwd share --stdin
    chown -R share:share /tmp/share
}


function create_users() { 
    useradd -m $MAKEUSER && usermod -aG wheel lektor
    mkdir /home/$MAKEUSER/{dekstop,download,image,audio,project,share,model,video}
    chown -R $MAKEUSER:$MAKEUSER /home/$MAKEUSER/*
    chmod -aG share $MAKEUSERl
    setfacl -Rm u:$MAKEUSERl:rwx /tmp/share
    setfacl -Rm u:$MAKEUSERl:rwx /var/lib/libvirt/images
}


function remove_roots() {
    passwd -l root
}


function setup_kernel() {
   
    if [[ $PROTOCOL == 'admiral' ]];then
        echo "intel_iommu=on i915.fastboot=1" > /etc/cmdline.d/02-mods.conf
        yes | pacman -S linux-hardened linux-firmware mkinitcpio intel-ucode bubblewrap-suid --noconfirm
    if

    mv /boot/intel-ucode.img /boot/vmlinuz-linux-hardened /boot/kernel
    bootctl --path=/boot install
    touch /etc/vconsole.conf

    echo "rd.luks.uuid=$(blkid -s UUID -o value /dev/$DISKROOT) root=/dev/proc/root" > /etc/cmdline.d/01-boot.conf
    echo "data UUID=$(blkid -s UUID -o value /dev/$DISKDATA) none" >> /etc/crypttab
}


function setup_secure() {

    pacman -S tang --noconfirm
    systemctl enable tangd.socket


    pacman -S firewalld
    systemctl enable firewalld


    pacman -S apparmor --noconfirm
    echo "lsm=landlock,lockdown,yama,integrity,apparmor,bpf" >> /etc/cmdline.d/03-secs.conf
    systemctl enable apparmor.service


    sudo pacman -S gnome-keyring libsecret seahorse keepassxc libpwquality --noconfirm
    mkdir /home/lektor/.gnupg


    echo "pinentry-program /usr/bin/pinentry-gnome3" > /home/lektor/.gnupg/gpg-agent.conf
    chown -R lektor:lektor /home/lektor/.gnupg


    sudo ln -s /usr/lib/seahorse/ssh-askpass /usr/lib/ssh/ssh-askpass
    echo "Path askpass /usr/lib/seahorse/ssh-askpass" >> /etc/sudo.conf


    systemctl --global enable gnome-keyring-daemon.socket
    systemctl --global enable  gcr-ssh-agent.socket
}


## lanjutkan ke desktop
