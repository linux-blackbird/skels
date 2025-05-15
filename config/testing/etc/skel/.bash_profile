#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc


## update

function update() {
    sudo reflector --save /etc/pacman.d/mirrorlist --counrty Indonesia,Singapore --protocol https --latest 5 &&
    yay &&
    sudo pacman -Scc
}