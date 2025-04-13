#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc


## launch hyprland
if uwsm check may-start; then
  exec uwsm start hyprland.desktop
fi

