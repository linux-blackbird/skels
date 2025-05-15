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
            cryptsetup luksOpen $DISKROOT lvm_root &&
            echo 'encrypted root volume is ready'
            sleep 2
        else
            cryptsetup luksOpen $DISKROOT lvm_root &&
            echo 'encrypted root volume is ready' &&
            sleep 2
        fi
        

        if [[ ! -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksFormat $DISKDATA &&
            cryptsetup luksOpen $DISKDATA lvm_data &&
            echo 'encrypted data volume is ready'
            sleep 2
        else
            cryptsetup luksOpen $DISKDATA lvm_data &&
            echo 'encrypted data volume is ready' &&
            sleep 2
        fi

    else

        if [[ -e /dev/mapper/lvm_root  ]];then
            cryptsetup luksOpen $DISKROOT lvm_root &&
            echo 'encrypted root volume is ready' &&
            sleep 2
        else
            echo 'error : lvm_root volume not found' &&
            exit 1
        fi

        if [[ -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksOpen $DISKDATA lvm_data &&
            echo 'encrypted data volume is ready' &&
            sleep 2
        else
            echo 'error : lvm_data volume not found' &&
            exit 1
        fi
    fi
}


function parted_root() {

    ## validation procedure
    if [[ ! -e /dev/mapper/lvm_root ]];then
        echo 'error : lvm_root partition not found'
        exit 1
    fi

    if [[ ! -z $LVMPROOT ]];then
        echo 'error : logical volume root size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMPVARS ]];then
        echo 'error : logical volume vars size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMPVTMP ]];then
        echo 'error : logical volume vtmp size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMPVLOG ]];then
        echo 'error : logical volume vlog size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMPVAUD ]];then
        echo 'error : logical volume vaud size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMPSWAP ]];then
        echo 'error : logical volume swap size its not define at profile'
        exit 1
    fi

    ## create logical volume
    if [[ ! -d /dev/proc ]];then
        pvcreate /dev/mapper/lvm_root
        vgcreate proc /dev/mapper/lvm_root
        echo 'proc volume group is created';
        sleep 1
    fi

    if [[ ! -e /dev/proc/root  ]];then
        yes | lvcreate -L $LVMPROOT proc -n root &&
        echo 'root logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/proc/vars ]];then
        yes | lvcreate -L $LVMPVARS proc -n vars &&
        echo 'var logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/proc/vtmp ]];then
        yes | lvcreate -L $LVMPVTMP proc -n vtmp &&
        echo 'var/tmp logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/proc/vlog ]];then
        yes | lvcreate -L $LVMPVTMP proc -n vlog &&
        echo 'var/log logical volume is created';
        sleep 1
    fi 

    if [[ ! -e /dev/proc/vaud ]];then
        yes | lvcreate -L $LVMPVAUD proc -n vaud &&
        echo 'var/log/audit logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/proc/swap ]];then
        yes | lvcreate -l100%FREE proc -n swap
        echo 'swap logical volume is created';
        sleep 1
    fi
}


function parted_data() {

    ## validation procedure
    if [[ $PROCEDUR != 'install' ]];then
        return;
    fi

    if [[ ! -e /dev/mapper/lvm_data ]];then
        echo 'error : logical volume data not found'
        exit 1
    fi

    if [[ ! -z $LVMDHOME ]];then
        echo 'error : logical volume home size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMDPODS ]];then
        echo 'error : logical volume pods size its not define at profile'
        exit 1
    fi

    if [[ ! -z $LVMDHOST ]];then
        echo 'error : logical volume host size its not define at profile'
        exit 1
    fi


    ## create logical volume
    if [[ ! -e /dev/data  ]];then
        pvcreate /dev/mapper/lvm_data
        vgcreate data /dev/mapper/lvm_data
        echo 'lvm_data partition is created';
    fi
  
    if [[ ! -e /dev/data/home  ]];then
        yes | lvcreate -L $LVMDHOME data -n home
        echo 'home logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/data/pods ]];then
        yes | lvcreate -L $LVMDPODS data -n pods
        echo 'pods logical volume is created';
        sleep 1
    fi

    if [[ ! -e /dev/data/host  ]];then
        yes | lvcreate -l $LVMDHOST data -n host
        echo 'host logical volume is created';
        sleep 1
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


function instal_main() {
    prepar_luks &&
    parted_root &&
    parted_data && 
    format_disk &&
    mounts_disk &&
    deploy_base &&
    migrat_envi &&
    migrat_desk &&
    arch-chroot /mnt /bin/sh -c '/bin/sh /install/post.sh' 
}


function instal_init() {
    instal_main && sleep 2 &&
    umount -R /mnt &&
    reboot
}

instal_init

