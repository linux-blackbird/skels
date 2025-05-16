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


if [[ ! -z $2 ]];then
    PROCEDUR=$2  #install | reset
fi


## load source
source /root/conf/users/$USERNAME
source /root/conf/protocol/$PROTOCOL
source /root/conf/userpack/$USERPACK


## begin operation
if [[ -d /mnt/install ]];then
    umount -R /mnt/install
    rm -r /mnt/install
fi


function prepar_luks() {

    if [[ $PROCEDUR == "install" ]];then
        
        cryptsetup luksFormat $DISKVAUL &&
        sleep 2
        
        if [[ ! -e /dev/mapper/lvm_root  ]];then
            cryptsetup luksFormat $DISKROOT &&
            cryptsetup luksOpen $DISKROOT lvm_root &&
            echo 'encrypted root volume is ready'
            sleep 2
        fi
        

        if [[ ! -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksFormat $DISKDATA &&
            cryptsetup luksOpen $DISKDATA lvm_data &&
            echo 'encrypted data volume is ready'
            sleep 2
        fi

    else

        if [[ ! -e /dev/mapper/lvm_root  ]];then
            cryptsetup luksOpen $DISKROOT lvm_root &&
            echo 'encrypted root volume is ready' &&
            sleep 2
        fi

        if [[ ! -e /dev/mapper/lvm_data  ]];then
            cryptsetup luksOpen $DISKDATA lvm_data &&
            echo 'encrypted data volume is ready' &&
            sleep 2
        fi
    fi
}


function parted_root() {

    ## validation procedure
    if [[ ! -e /dev/mapper/lvm_root ]];then
        echo 'error : lvm_root partition not found'
        exit 1
    fi

    if [[ -z $LVMPROOT ]];then
        echo 'error : logical volume root size its not define at profile'
        exit 1
    fi

    if [[ -z $LVMPVARS ]];then
        echo 'error : logical volume vars size its not define at profile'
        exit 1
    fi

    if [[ -z $LVMPVTMP ]];then
        echo 'error : logical volume vtmp size its not define at profile'
        exit 1
    fi

    if [[ -z $LVMPVLOG ]];then
        echo 'error : logical volume vlog size its not define at profile'
        exit 1
    fi

    if [[ -z $LVMPVAUD ]];then
        echo 'error : logical volume vaud size its not define at profile'
        exit 1
    fi


    ## create logical volume
    if [[ ! -d /dev/proc ]];then
        pvcreate /dev/mapper/lvm_root
        vgcreate proc /dev/mapper/lvm_root
    fi

    if [[ ! -e /dev/proc/root ]];then
        yes | lvcreate -L $LVMPROOT proc -n root
    fi

    if [[ ! -e /dev/proc/vars ]];then
        yes | lvcreate -L $LVMPVARS proc -n vars
    fi

    if [[ ! -e /dev/proc/vtmp ]];then
        yes | lvcreate -L $LVMPVTMP proc -n vtmp
    fi

    if [[ ! -e /dev/proc/vlog ]];then
        yes | lvcreate -L $LVMPVTMP proc -n vlog
        sleep 1
    fi 

    if [[ ! -e /dev/proc/vaud ]];then
        yes | lvcreate -L $LVMPVAUD proc -n vaud
        sleep 1
    fi

    if [[ ! -e /dev/proc/swap ]];then
        yes | lvcreate -l100%FREE proc -n swap
        sleep 1
    fi
}


function parted_data() {

    ## validation procedure
    if [[ $PROCEDUR == 'install' ]];then

         if [[ ! -e /dev/mapper/lvm_data ]];then
            echo 'error : logical volume data not found'
            exit 1
        fi

        if [[ -z $LVMDHOME ]];then
            echo 'error : logical volume home size its not define at profile'
            exit 1
        fi


        ## create logical volume
        if [[ ! -e /dev/data  ]];then
            pvcreate /dev/mapper/lvm_data
            vgcreate data /dev/mapper/lvm_data
        fi
    
        if [[ ! -e /dev/data/home ]];then
            yes | lvcreate -L $LVMDHOME data -n home
            sleep 1
        fi

        if [[ ! -e /dev/data/pods ]]&&[[ ! -z $LVMDPODS ]];then
            yes | lvcreate -L $LVMDPODS data -n pods
            sleep 1
        fi

        if [[ ! -e /dev/data/host ]]&&[[ ! -z $LVMDHOST ]];then
            yes | lvcreate -l $LVMDHOST data -n host
            sleep 1
        fi
    fi
}


function format_disk() {

    if [[ $PROCEDUR == 'install' ]]&&[[ ! -e /mnt/install/boot ]];then
        yes | mkfs.vfat -F32 -S 4096 -n BOOT $DISKBOOT > /dev/null
    fi

    if [[ $PROCEDUR == 'install' ]]&&[[ ! -e /mnt/install/home ]];then
        yes | mkfs.ext4 -b 4096 /dev/data/home > /dev/null
    fi

    if [[ $PROCEDUR == 'install' ]]&&[[ ! -e /mnt/install/var/lib/containers ]]&&[[ ! -z $LVMDPODS ]];then
        mkfs.xfs -fs size=4096 /dev/data/pods > /dev/null
    fi

    if [[ $PROCEDUR == 'install' ]]&&[[ ! -e /mnt/install/var/lib/libvirt/images ]]&&[[ ! -z $LVMDHOST ]];then
        mkfs.xfs -fs size=4096 /dev/data/host > /dev/null
    fi

    if [[ ! -e /mnt/install/ ]];then
        yes | mkfs.ext4 -b 4096 /dev/proc/root > /dev/null
    fi

    if [[ ! -e /mnt/install/var ]];then
        yes | mkfs.ext4 -b 4096 /dev/proc/vars > /dev/null
    fi

    if [[ ! -e /mnt/install/var/tmp ]];then
        yes | mkfs.ext4 -b 4096 /dev/proc/vtmp > /dev/null
    fi

    if [[ ! -e /mnt/install/var/log ]];then
        yes | mkfs.ext4 -b 4096 /dev/proc/vlog > /dev/null
    fi

    if [[ ! -e /mnt/install/var/audit ]];then
        yes | mkfs.ext4 -b 4096 /dev/proc/vaud > /dev/null
    fi

    swapoff /dev/proc/swap > /dev/null
    yes | mkswap /dev/proc/swap  > /dev/null
}


function mounts_disk() {

    ## root mounting
    if [[ ! -d /mnt/install/ ]];then
        mkdir /mnt/install
        mount /dev/proc/root /mnt/install/ &&
        echo 'mount root'
        sleep 1
    fi

    ## boot mounting
    if [[ ! -d /mnt/install/boot ]];then
        mkdir /mnt/install/boot &&
        mount -o uid=0,gid=0,fmask=0077,dmask=0077 $DISKBOOT /mnt/install/boot &&
        echo 'mount boot'
        sleep 1
    fi

    ## vars mounting
    if [[ ! -d /mnt/install/var ]];then
        mkdir /mnt/install/var &&
        mount -o defaults,rw,nosuid,nodev,noexec,relatime /dev/proc/vars /mnt/install/var &&
        echo 'mount vars'
        sleep 1
    fi

    ## vtmp mounting
    if [[ ! -d /mnt/install/var/tmp ]];then
        mkdir /mnt/install/var/tmp &&
        mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vtmp /mnt/install/var/tmp &&
        echo 'mount vtmp'
        sleep 1
    fi

    ## vlog mounting
    if [[ ! -d /mnt/install/var/log ]];then
        mkdir /mnt/install/var/log &&
        mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vlog /mnt/install/var/log &&
        echo 'mount vlog'
        sleep 1
    fi

    ## vaud mounting
    if [[ ! -d /mnt/install/var/log/audit ]];then
        mkdir /mnt/install/var/log/audit &&
        mount -o rw,nosuid,nodev,noexec,relatime /dev/proc/vaud /mnt/install/var/log/audit &&
        echo 'mount vaud'
        sleep 1
    fi

    ## home mounting
    if [[ ! -d /mnt/install/home ]];then
        mkdir /mnt/install/home &&
        mount -o rw,nosuid,nodev,noexec,relatime /dev/data/home /mnt/install/home &&
        echo 'mount home'
        sleep 1
    fi
 
    ## pods mounting
    mkdir /mnt/install/var/lib

    if [[ ! -d /mnt/install/var/lib/containers ]]&&[[ ! -z $LVMDPODS ]];then
        mkdir /mnt/install/var/lib/containers &&
        mount /dev/data/pods /mnt/install/var/lib/containers &&
        echo 'mount pods'
        sleep 1
    fi

    ## host mounting
    if [[ ! -d /mnt/install/var/lib/libvirt/images ]]&&[[ ! -z $LVMDHOST ]];then
        mkdir /mnt/install/var/lib/libvirt /mnt/install/var/lib/libvirt/images &&
        mount /dev/data/host /mnt/install/var/lib/libvirt/images &&
        echo 'mount host'
        sleep 1
    fi

    ## swap mounting
    swapon /dev/proc/swap
    echo 'mount swap'
    sleep 1
}


function deploy_base() {

    reflector -f 5 -c id --save /etc/pacman.d/mirrorlist

    pacstrap /mnt/install/ $PACKBASE $PACKVARS
    genfstab -U /mnt/install/ > /mnt/install/etc/fstab 
    cp /etc/systemd/network/* /mnt/install/etc/systemd/network/

    ## cis tmpfs rules
    echo 'tmpfs     /tmp        tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/install/etc/fstab
    echo 'tmpfs     /dev/shm    tmpfs   defaults,rw,nosuid,nodev,noexec,relatime,size=1G    0 0' >> /mnt/install/etc/fstab




    ## prepare protocol env
    mkdir /mnt/install/setup
    cat /root/conf/users/$USERNAME > /mnt/install/setup/setupenvi
    cat /root/conf/protocol/$PROTOCOL >> /mnt/install/setup/setupenvi
    cat /root/conf/userpack/$USERPACK >> /mnt/install/setup/setupenvi
   

    ## migrate protocol configuration
    cp -fr /root/conf/config/$PROTOCOL/* /mnt/install


    ## protocol installation script
    arch-chroot /mnt/install/ /bin/bash /setup/system
}


prepar_luks &&
parted_root &&
parted_data && 
format_disk &&
mounts_disk &&
deploy_base &&
umount -R /mnt/install &&
reboot


