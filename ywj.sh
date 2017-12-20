# create by ywj to make custom changes

# You can also use tput command to set terminal and modify the prompt settings. For example, to display RED color prompt using a tput:
#export PS1="\[$(tput setaf 1)\]\u@\h:\w $ \[$(tput sgr0)\]"
#A list of handy tput command line options
#
#    tput bold - Bold effect
#    tput rev - Display inverse colors
#    tput sgr0 - Reset everything
#    tput setaf {CODE}- Set foreground color, see color {CODE} table below for more information.
#    tput setab {CODE}- Set background color, see color {CODE} table below for more information.
#
#Various color codes for the tput command
#Color {code} 	Color
#0 	Black
#1 	Red
#2 	Green
#3 	Yellow
#4 	Blue
#5 	Magenta
#6 	Cyan
#7 	White

PS1="\[$(tput setaf 6)\][\u@\w]\\$ \[$(tput sgr0)\]"
#PROMPT_COMMAND='printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
#PROMPT_COMMAND="echo -n [$(date +%H:%M:%S)]"
PROMPT_COMMAND='printf "\033]0;%s\007" "${PWD##*/}"'
