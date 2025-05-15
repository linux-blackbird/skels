#!/bin/bash

source /setup/user.sh
sleep 1


source /setup/protocol.sh
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
    echo $PASSWORD | passwd --stdin lektor &&
    usermod -aG wheel lektor &&
    mkdir /home/lektor/{dekstop,download,image,audio,project,share,model,video}
    chown -R lektor:lektor /home/lektor/*
    echo 'lektor user created'
    sleep 5
}


function create_share() {
    mkdir /tmp/share &&
    useradd -d /tmp/share share && 

    echo $PASSWORD | passwd --stdin share
    chown -R share:share /tmp/share

    echo 'share user created'
    sleep 5
}


function create_users() { 
    useradd -m $USERNAME &&
    chage -d 0 "${USERNAME}"
    mkdir /home/$USERNAME/{dekstop,download,image,audio,project,share,model,video} &&
    chown -R $USERNAME:$USERNAME /home/$USERNAME/* &&
    usermod -aG share $USERNAME &&
    setfacl -Rm u:$USERNAME:rwx /var/lib/libvirt/images &&
    echo 'custom user created'
    sleep 5
}


function remove_roots() {
    passwd -l root
     echo 'root account is locked'
}

config_based &&
create_admin &&
create_share &&
create_users &&
remove_roots 