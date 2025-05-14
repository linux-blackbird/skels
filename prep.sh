#!/bin/bash

PROTOCOL=$1 
PROCEDUR=$2     #reset or swipe#
DISKBOOT='/dev/nvme0n1p1'
DISKVAUL='/dev/nvme0n1p2'
DISKROOT='/dev/nvme0n1p3'
DISKDATA='/dev/nvme0n1p4'
PACKADMR=""
PACKCNTR=""


function format_luks() {
    if [[ $PROCEDUR === 'swipe' ]];then
        cryptsetup luksFormat /dev/nvme0n1p2 &&
        cryptsetup luksFormat /dev/nvme0n1p3 &&
        cryptsetup luksFormat /dev/nvme0n1p4
    fi
}


function opened_luks() {
    if [[ $PROCEDUR === 'reset' ]];then
        cryptsetup luksOpen /dev/nvme0n1p3 lvm_root &&
        cryptsetup luksOpen /dev/nvme0n1p4 lvm_data
    fi
}


function parted_root_admiral() {
    pvcreate /dev/mapper/lvm_root &&
    vgcreate proc /dev/mapper/lvm_root &&
    lvcreate -L 15G  proc -n root &&
    lvcreate -L 10G  proc -n vars &&
    lvcreate -L 1G   proc -n vtmp &&
    lvcreate -L 2.5G proc -n root &&
    lvcreate -L 1.5G proc -n root &&
    lvcreate -l 100%FREE proc -n swap
}


function parted_data_admiral() {
    pvcreate /dev/mapper/lvm_data
    vgcreate data /dev/mapper/lvm_data
    lvcreate -L 100G data -n home
    lvcreate -L 30G data -n pods
    lvcreate -l 100%FREE data -n host
}


function parted_data_control() {
    pvcreate /dev/mapper/lvm_data
    vgcreate data /dev/mapper/lvm_data
    lvcreate -L 600G data -n home
    lvcreate -L 100G data -n pods
    lvcreate -l 100%FREE data -n host
}


function parted_disk() {

    if [[ $PROTOCOL === 'admiral' ]];then
        echo 'format root admiral'
        echo 'format data admiral'
    fi

    if [[ $PROTOCOL === 'control' ]];then
        echo 'format root control'
        echo 'format data control'
    fi
}


function format_disk() {

    yes | mkfs.vfat -F32 -S 4096 -n BOOT /dev/nvme0n1p1
    yes | mkfs.ext4 -b 4096 /dev/proc/root
    yes | mkfs.ext4 -b 4096 /dev/proc/vars
    yes | mkfs.ext4 -b 4096 /dev/proc/vtmp
    yes | mkfs.ext4 -b 4096 /dev/proc/vlog
    yes | mkfs.ext4 -b 4096 /dev/proc/vaud
    yes | mkswap /dev/proc/swap
    yes | mkfs.ext4 -b 4096 /dev/data/home
    mkfs.xfs -fs size=4096 /dev/data/pods
    mkfs.xfs -fs size=4096 /dev/data/host
}


function mounts_disk() {

    ## root mounting
    mount /dev/proc/root /mnt &&

    ## boot mounting
    mkdir /mnt/boot
    mount -o uid=0,gid=0,fmask=0077,dmask=0077 /dev/nvme0n1p1 /mnt/boot

    ## vars mounting
    mkdir /mnt/var
    mount /dev/proc/vars /mnt/var

    ## vtmp mounting
    mkdir /mnt/var/tmp
    mount /dev/proc/vtmp /mnt/var/tmp

    ## vlog mounting
    mkdir /mnt/var/log
    mount /dev/proc/vlog /mnt/var/log

    ## vaud mounting
    mkdir /mnt/var/log/audit
    mount /dev/proc/vaud /mnt/var/log/audit

    ## home mounting
    mkdir /mnt/home
    mount /dev/data/home /mnt/home

    ## pods mounting
    mkdir /mnt/var/lib /mnt/var/lib/libvirt /mnt/var/lib/libvirt/images
    mount /dev/data/host /mnt/var/lib/libvirt/images

    ## host mounting
    mkdir /mnt/var/lib/containers
    mount /dev/data/pods /mnt/var/lib/containers

    ## swap mounting
    swapon /dev/proc/swap
}


function deploy_base() {
    pacstrap /mnt base base-devel neovim git openssh polkit xfsprogs lvm2 less 
    cp /etc/systemd/network/* /mnt/etc/systemd/network/
    genfstab -U /mnt > /mnt/etc/fstab
    echo "tmpfs   /tmp         tmpfs   rw,noexec,nodev,nosuid,size=2G          0  0" >> /mnt/etc/fstab
}


function deploy_conf() {

    git clone https://github.com/linux-blackbird/conf /deploy

    if [[ $PROTOCOL == 'admiral' ]];then
        cp -f /deploy/admiral/* /mnt/
    fi

    if [[ $PROTOCOL == 'control' ]];then
        cp -f /deploy/control/* /mnt/
    fi

    cp /deploy/post.sh /mnt
}


function blackbird_prep() {
    format_luks &&
    opened_luks &&
    parted_data &&
    parted_disk &&
    format_disk &&
    deploy_base &&
    deploy_conf &&
    arch-chroot /mnt /bin/sh -c '/bin/sh post.sh'
}


blackbird_prep;