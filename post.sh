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
   
    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        echo "intel_iommu=on i915.fastboot=1" > /etc/cmdline.d/02-mods.conf
        yes | pacman -S linux-hardened linux-firmware mkinitcpio intel-ucode bubblewrap-suid --noconfirm
    fi

    mv /boot/intel-ucode.img /boot/vmlinuz-linux-hardened /boot/kernel
    bootctl --path=/boot install
    touch /etc/vconsole.conf

    echo "rd.luks.uuid=$(blkid -s UUID -o value /dev/$DISKROOT) root=/dev/proc/root" > /etc/cmdline.d/01-boot.conf
    echo "data UUID=$(blkid -s UUID -o value /dev/$DISKDATA) none" >> /etc/crypttab
}

function setup_desktp() {
    /bin/bash /install/desktop
}


function setup_secure() {


    pacman -S firewalld --noconfirm
    systemctl enable firewalld


    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S tang --noconfirm
        systemctl enable tangd.socket
    fi



    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then

        pacman -S apparmor --noconfirm
        echo "lsm=landlock,lockdown,yama,integrity,apparmor,bpf" >> /etc/cmdline.d/03-secs.conf
        systemctl enable apparmor.service
    fi

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then

        sudo pacman -S gnome-keyring libsecret seahorse keepassxc libpwquality --noconfirm
        mkdir /home/lektor/.gnupg


        echo "pinentry-program /usr/bin/pinentry-gnome3" > /home/lektor/.gnupg/gpg-agent.conf
        chown -R lektor:lektor /home/lektor/.gnupg


        sudo ln -s /usr/lib/seahorse/ssh-askpass /usr/lib/ssh/ssh-askpass
        echo "Path askpass /usr/lib/seahorse/ssh-askpass" >> /etc/sudo.conf


        systemctl --global enable gnome-keyring-daemon.socket
        systemctl --global enable  gcr-ssh-agent.socket
    fi
}


function setup_mitiga() {

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S rsync grsync --noconfirm
    fi


    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        curl --output recovery.efi https://boot.netboot.xyz/ipxe/netboot.xyz.efi
        mv -f recovery.efi /boot/efi/rescue/
    fi

}


function setup_vhosts() {

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S qemu-base libvirt virt-manager openbsd-netcat --noconfirm
        systemctl enable libvirtd.socket
        usermod -aG libvirt lektor
        usermod -aG libvirt $MAKEUSER

        mkdir /var/lib/libvirt/images/master
        mkdir /var/lib/libvirt/images/testing
        mkdir /var/lib/libvirt/images/publish
    fi
}


function setup_podman() {

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S podman crun fuse-overlayfs podman-desktop podman-docker podman-compose --noconfirm
        chmod 4755 /opt/podman-desktop/chrome-sandbox 
        chown -R root:root /opt/podman-desktop/chrome-sandbox
        echo "unqualified-search-registries = ["docker.io"]" > /etc/containers/registries.conf.d/10-userspace-registries.conf 
        git clone https://github.com/linux-blackbird/podlet.git /tmp/script
        chmod +x /tmp/script/* 
        cp /tmp/script/* /usr/bin
    fi
}


function setup_tweaks() {
    pacman -S reflector --noconfirm 
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/backupmirror 
}


function setup_tunned() {

    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S tuned tuned-ppd --noconfirm
        systemctl enable tuned-ppd
    fi


    if [[ $PROTOCOL == "testing" ]]||[[ $PROTOCOL == 'admiral' ]];then
        pacman -S irqbalance --noconfirm
        systemctl enable irqbalance.service
    fi
}

function setup_cleans() {
    rm -fr /install &&
    mkinitcpio -P
}


config_based &&
create_admin &&
create_share &&
create_users &&
remove_roots &&
setup_kernel &&
setup_secure &&
setup_mitiga &&
setup_vhosts &&
setup_podman &&
setup_tweaks && 
setup_tunned &&
setup_cleans &&
exit
