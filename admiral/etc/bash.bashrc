#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Prevent doublesourcing
if [[ -z "${BASHRCSOURCED}" ]] ; then
  BASHRCSOURCED="Y"
  # the check is bash's default value
  [[ "$PS1" = '\s-\v\$ ' ]] && PS1='[\u@\h \W]\$ '
  case ${TERM} in
    Eterm*|alacritty*|aterm*|foot*|gnome*|konsole*|kterm*|putty*|rxvt*|tmux*|xterm*)
      PROMPT_COMMAND+=('printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')
      ;;
    screen*)
      PROMPT_COMMAND+=('printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')
      ;;
  esac
fi

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi


## bash themes
function bash_themes() {

	if [ $(id -u) -eq 0 ];then
		PS1='\[\e[38;5;196m\](\#)\[\e[0m\] \[\e[38;5;196m\]\u\[\e[0m\] \[\e[38;5;196m\](\[\e[0m\] \[\e[38;5;196m\]\t\[\e[0m\] \[\e[38;5;196m\]|\[\e[0m\] \[\e[38;5;196m\]\w\[\e[0m\] \[\e[38;5;196m\])\n\[\e[0m\] \[\e[38;5;196m\]|-->\[\e[0m\] '
	elif [ $(id -u) -ne 0 -a -d .git ];then
		PROMPT_COMMAND='PS1_CMD1=$(git branch --show-current 2>/dev/null)'; PS1='(\#) \[\e[38;5;214m\]\u\[\e[38;5;220m\]@\[\e[38;5;214m\]\h\[\e[0m\] ( \[\e[38;5;39m\]\t\[\e[0m\] | \[\e[38;5;39m\]\w\[\e[0m\] ) --> ( \[\e[38;5;40m\]branch\[\e[0m\] : \[\e[38;5;40m\]${PS1_CMD1}\[\e[0m\] )\n |--> '
	else
		PS1='\[\e[38;5;214m\](\[\e[38;5;215m\]\#\[\e[38;5;214m\])\[\e[0m\] \[\e[38;5;214m\]\u\[\e[38;5;208m\]@\[\e[38;5;214m\]\h\[\e[0m\] \[\e[38;5;214m\](\[\e[0m\] \[\e[38;5;45m\]\t\[\e[0m\] \[\e[38;5;214m\]|\[\e[0m\] \[\e[38;5;45m\]\w\[\e[0m\] \[\e[38;5;214m\])\n\[\e[0m\] \[\e[38;5;214m\]|-->\[\e[0m\] '
	fi
}
bash_themes