#!/bin/bash

source /setup/user.sh
cat /setup/user.sh
sleep 1


source /setup/protocol.sh
cat /setup/user.sh
sleep 1


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
    useradd -m lektor && 
    echo "1511" | passwd lektor --stdin &&
    usermod -aG wheel lektor &&
    mkdir /home/lektor/{dekstop,download,image,audio,project,share,model,video}
    chown -R lektor:lektor /home/lektor/*
    echo 'lektor user created'
    sleep 2
}


function create_share() {
    mkdir /tmp/share &&
    useradd -d /tmp/share share && 
    echo "1511" | passwd share --stdin
    chown -R share:share /tmp/share

    echo 'share user created'
    sleep 2
}


function create_users() { 
    useradd -m $MAKEUSER &&
    echo "1511" | passwd $MAKEUSER --stdin
    mkdir /home/$MAKEUSER/{dekstop,download,image,audio,project,share,model,video} &&
    chown -R $MAKEUSER:$MAKEUSER /home/$MAKEUSER/* &&
    usermod -aG share $MAKEUSERl &&
    setfacl -Rm u:$MAKEUSERl:rwx /tmp/share &&
    setfacl -Rm u:$MAKEUSERl:rwx /var/lib/libvirt/images
    echo 'custom user created'
    sleep 2
}


function remove_roots() {
    passwd -l root
}

config_based &&
create_admin &&
create_share &&
remove_roots 