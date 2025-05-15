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

        if [[ ! -e /dev/data/host  ]];then
            yes | pvcreate /dev/mapper/lvm_root &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | vgcreate proc /dev/mapper/lvm_root &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -L $LVMPROOT proc -n root &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -L $LVMPVARS proc -n vars &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -L $LVMPVTMP proc -n vtmp &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -L $LVMPVTMP proc -n vlog &&
            sleep 2
        fi 

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -L $LVMPVAUD proc -n vaud &&
            sleep 2
        fi

        if [[ ! -e /dev/data/host  ]];then
            yes | lvcreate -l100%FREE proc -n swap
            sleep 2
        fi
    fi
}


function parted_data() {


    if [[ $PROCEDUR == 'install' ]];then

        if [[ ! -e /dev/mapper/lvm_data  ]];then
            pvcreate /dev/mapper/lvm_data
            vgcreate data /dev/mapper/lvm_data
        fi

       
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
    echo 'mount root'
    sleep 1

    ## boot mounting
    mkdir /mnt/boot &&
    mount -o uid=0,gid=0,fmask=0077,dmask=0077 $DISKBOOT /mnt/boot &&
    echo 'mount boot'
    sleep 1

    ## vars mounting
    mkdir /mnt/var &&
    mount /dev/proc/vars /mnt/var &&
    echo 'mount vars'
    sleep 1

    ## vtmp mounting
    mkdir /mnt/var/tmp &&
    mount /dev/proc/vtmp /mnt/var/tmp &&
    echo 'mount vtmp'
    sleep 1

    ## vlog mounting
    mkdir /mnt/var/log &&
    mount /dev/proc/vlog /mnt/var/log &&
    echo 'mount vlog'
    sleep 1

    ## vaud mounting
    mkdir /mnt/var/log/audit &&
    mount /dev/proc/vaud /mnt/var/log/audit &&
    echo 'mount vaud'
    sleep 1

    ## home mounting
    mkdir /mnt/home &&
    mount /dev/data/home /mnt/home &&
    echo 'mount home'
    sleep 1
 
    ## pods mounting
    mkdir /mnt/var/lib /mnt/var/lib/libvirt /mnt/var/lib/libvirt/images &&
    mount /dev/data/host /mnt/var/lib/libvirt/images &&
    echo 'mount pods'
    sleep 1

    ## host mounting
    mkdir /mnt/var/lib/containers &&
    mount /dev/data/pods /mnt/var/lib/containers &&
    echo 'mount host'
    sleep 1

    ## swap mounting
    swapon /dev/proc/swap
    echo 'mount swap'
    sleep 1
}


function deploy_base() {

    pacstrap /mnt $PACKBASE
    genfstab -U /mnt > /mnt/etc/fstab 
    cp /etc/systemd/network/* /mnt/etc/systemd/network/
    echo "tmpfs   /tmp         tmpfs   rw,noexec,nodev,nosuid,size=2G          0  0" >> /mnt/etc/fstab
}


function migrat_envi() {
    mkdir /mnt/install
    chmod +x /root/conf/post.sh
    cp /root/conf/post.sh /mnt/install
    cp /root/conf/users/$USERNAME /mnt/install/userenv 
    cp /root/conf/protocol/$PROTOCOL /mnt/install/protcolenv
    cp -fr /root/conf/config/$PROTOCOL/* /mnt
}


function migrat_desk() {

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        cp /root/conf/desktop/hyprland /mnt/install/desktop
    fi
}


function instal_prep() {
    prepar_luks &&
    parted_root &&
    parted_data && 
    format_disk &&
    mounts_disk &&
    deploy_base &&
    migrat_envi &&
    migrat_desk &&
    arch-chroot /mnt /bin/sh -c '/bin/sh /install/post.sh'


    ## finishing
    read -p "Installation successfull, do you want reboot now : [y/n] " REBOOTNOW
    if [[ $REBOOTNOW === "y" ]] || [[ $REBOOTNOW === "Y" ]]lthen
        umount -R /mnt
        reboot
    fi
}


instal_prep;