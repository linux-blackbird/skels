#!/bin/bash

## parameter check
if [[ -z $1 ]];then
    echo 'error : user name paramter is empty';
    exit 1;  
fi

echo $1

if [ ! -e /root/conf/users/$1 ];then
    echo 'error : your account is suspended or never exist';
    exit 1;
fi



## variable
USERNAME=$1
PROCEDUR="reset"
PACKBASE="base base-devel neovim git openssh polkit xfsprogs lvm2 less"



if [[ ! -z $2 ]];then
    PROCEDUR=$2  #install | reset
fi



## load source
source /root/conf/users/$USERNAME
source /root/conf/protocol/$PROTOCOL



## begin operation
function prepar_luks() {

    if [[ $PROCEDUR == "install" ]];then
        
        cryptsetup luksFormat $DISKVAUL &&
        sleep 2
        

        if [[ ! -e /dev/mapper/lvm_root  ]];then
            cryptsetup luksFormat $DISKROOT &&
            cryptsetup luksOpen $DISKROOT lvm_root
            sleep 2
        fi
        
        if [[ ! -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksFormat $DISKDATA
            cryptsetup luksOpen $DISKDATA lvm_data
            sleep 2
        fi

    else

        if [[ ! -e /dev/mapper/lvm_root  ]];then
            cryptsetup luksOpen $DISKROOT lvm_root
            sleep 5
        fi

        if [[ ! -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksOpen $DISKDATA lvm_data
            sleep 5
        fi
    fi
}


function parted_root() {

    if [[ ! -e /dev/mapper/lvm_root  ]];then
        yes | pvcreate /dev/mapper/lvm_root &&
        sleep 2
        yes | vgcreate proc /dev/mapper/lvm_root &&
        sleep 2
        yes | lvcreate -L $LVMPROOT proc -n root &&
        sleep 2
        yes | lvcreate -L $LVMPVARS proc -n vars &&
        sleep 2
        yes | lvcreate -L $LVMPVTMP proc -n vtmp &&
        sleep 2
        yes | lvcreate -L $LVMPVTMP proc -n vlog &&
        sleep 2
        yes | lvcreate -L $LVMPVAUD proc -n vaud &&
        sleep 2
        yes | lvcreate -l100%FREE proc -n swap
        sleep 2
    fi
}


function parted_data() {

    if [[ -e /dev/mapper/lvm_data  ]];then
        return
    fi

    if [[ $PROCEDUR == 'install' ]];then

        pvcreate /dev/mapper/lvm_data
        vgcreate data /dev/mapper/lvm_data

        if [[ ! -z $LVMDHOME ]];then
            if [[ ! -e /dev/data/home  ]];then
                yes | lvcreate -L $LVMDHOME data -n home
            fi
        fi

        if [[ ! -z $LVMDPODS ]];then
            if [[ ! -e /dev/data/pods  ]];then
                yes | lvcreate -L $LVMDPODS data -n pods
            fi
        fi

        if [[ ! -z $LVMDHOST ]];then
            if [[ ! -e /dev/data/host  ]];then
                yes | lvcreate -l $LVMDHOST data -n host
            fi
        fi
    fi
}


function format_disk() {

    if [[ $PROCEDUR == 'install' ]];then
        yes | mkfs.vfat -F32 -S 4096 -n BOOT $DISKBOOT &&
        yes | mkfs.ext4 -b 4096 /dev/data/home &&
        mkfs.xfs -fs size=4096 /dev/data/pods &&
        mkfs.xfs -fs size=4096 /dev/data/host
    fi

    yes | mkfs.ext4 -b 4096 /dev/proc/root &&
    yes | mkfs.ext4 -b 4096 /dev/proc/vars &&
    yes | mkfs.ext4 -b 4096 /dev/proc/vtmp &&
    yes | mkfs.ext4 -b 4096 /dev/proc/vlog &&
    yes | mkfs.ext4 -b 4096 /dev/proc/vaud &&
    yes | mkswap /dev/proc/swap 
}


function mounts_disk() {

    ## root mounting
    mount /dev/proc/root /mnt &&
    sleep 1

    ## boot mounting
    mkdir /mnt/boot &&
    mount -o uid=0,gid=0,fmask=0077,dmask=0077 $DISKBOOT /mnt/boot &&
    sleep 1

    ## vars mounting
    mkdir /mnt/var &&
    mount /dev/proc/vars /mnt/var &&
    sleep 1

    ## vtmp mounting
    mkdir /mnt/var/tmp &&
    mount /dev/proc/vtmp /mnt/var/tmp &&
    sleep 1

    ## vlog mounting
    mkdir /mnt/var/log &&
    mount /dev/proc/vlog /mnt/var/log &&
    sleep 1

    ## vaud mounting
    mkdir /mnt/var/log/audit &&
    mount /dev/proc/vaud /mnt/var/log/audit &&
    sleep 1

    ## home mounting
    mkdir /mnt/home &&
    mount /dev/data/home /mnt/home &&
    sleep 1
 
    ## pods mounting
    mkdir /mnt/var/lib /mnt/var/lib/libvirt /mnt/var/lib/libvirt/images &&
    mount /dev/data/host /mnt/var/lib/libvirt/images &&
    sleep 1

    ## host mounting
    mkdir /mnt/var/lib/containers &&
    mount /dev/data/pods /mnt/var/lib/containers &&
    sleep 1

    ## swap mounting
    swapon /dev/proc/swap
    sleep 1
}


function deploy_base() {

    if [ pacstrap /mnt $PACKBASE ];then
        genfstab -U /mnt > /mnt/etc/fstab 
        cp /etc/systemd/network/* /mnt/etc/systemd/network/
        echo "tmpfs   /tmp         tmpfs   rw,noexec,nodev,nosuid,size=2G          0  0" >> /mnt/etc/fstab
    fi
}


function migrat_envi() {
    mkdir /mnt/install
    chmod +x post.sh
    cp post.sh /mnt/install
    cp users/$1 /mnt/install/userenv 
    cp protocol/$PROTOCOL /mnt/install/protcolenv
    cp -fr config/$PROTOCOL/* /mnt
}


function instal_prep() {
    prepar_luks &&
    parted_root &&
    parted_data && 
    format_disk &&
    mounts_disk &&
    deploy_base &&
    deploy_conf &&
    create_envi &&
    arch-chroot /mnt /bin/sh -c '/bin/sh post.sh'    
}

instal_prep;