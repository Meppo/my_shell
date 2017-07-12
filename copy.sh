#!/bin/bash

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/my_script/shell_ipc}
logfile=${logfile:=/dev/stdout}
source $my_shell_ipc_path/log.sh

contents_array=(
    #0
    "This is test content, you can use option --arg1 replace <arg1> --arg2 replace <arg2> , try it!"
    #0
    "tftp -r router.sh -g <ip>; chmod +x router.sh; ./router.sh ip <ip> && ./router.sh app devices_app && ./router.sh 0 "
    #1
    "ifconfig enp3s0 192.168.1.33; tftp -m binary -l 192.168.1.6 -c put ra288.bin"
    #2
    "export LD_LIBRARY_PATH=/app/<app>/bin/"
    #3
    "export LD_LIBRARY_PATH=/app/igd_network/bin/; /app/igd_network/bin/igd_network_client   &"
    #4
    "killall igd_network_app; export LD_LIBRARY_PATH=/app/igd_network/bin/; /app/igd_network/bin/igd_network_client   &"
    #5
    "export LD_LIBRARY_PATH=/app/igd_network/bin/; ./igd_network_server   &"
    #6
    "export LD_LIBRARY_PATH=/app/igd_network/bin/; ./igd_network_client   &"
    #7
    "export LD_LIBRARY_PATH=/app/igd_network/bin/; ./srv_test   &"
    #8
    "export LD_LIBRARY_PATH=/tmp/;/lib/; ./igd_network_client   &"
    #9
    "alsfm 1 <mac>"
)
contents_args=(
    "arg1 arg2"
    "ip"    #0
    "null"  #1
    "app"   #2
    "null"  #3
    "null"  #4
    "null"  #5
    "null"  #6
    "null"  #7
    "null"  #8
    "mac"   #9
)
contents_num=${#contents_array[@]}

function copy_usage()
{
    echo "NAME:"
    echo "  ./$0 [index] [options]"
    echo ""
    echo "DESCRIPTION:"
    echo " the script used to copy the data with [index] to clipboard, "
    echo "      then you can paste the content whit middle mouse or SHIFT+INSERT."
    echo ""
    echo "Index-Content list:"
    local i=0
    while [ $i -lt $contents_num ]
    do
        echo "  $i: ${contents_array[$i]}"
        let i++
    done
    echo ""
    echo "OPTIONS:"
    echo "  some sentences need change special param with options:"
    echo "  --ip=<value>"
    echo "     some sentences need ip. will use the <value> replace <ip> "
    echo "  --mac=<value>"
    echo "  --app=<value>"
    echo ""
    echo "EXAMPLES:"
    echo "  ./$0 0 arg1=test_value1 arg2=test_value2"
}

function copy_func()
{
    # paste with middle mouse
    echo "$*" | xclip -selection x
    # paste with SHIFT+INSERT
    echo "$*" | xclip -selection c
}

# do things we need to do when excute this script directly,not source this script.
#   if source this script by other scripts, FUNCNAME[]: source main
if [ "${FUNCNAME[0]}" = "main" ];then

if [ $# -lt 1 ];then
    Error "too few argus"
    copy_usage
    exit 0
fi

# del duplicate args
i=0
j=0
tmp_args=(${contents_args[@]})
for ((i=0;i<$contents_num;i++))
do
    if [ "${tmp_args[i]}" = "null" ];then
        unset tmp_args[i]
        continue;
    fi

    for ((j=$contents_num-1;j>i;j--))
    do
        if [ "${tmp_args[i]}" = "${tmp_args[j]}" ];then
            unset tmp_args[j]
        fi
    done
done

i=0
uniq_num=${#tmp_args[@]}
uniq_options=
for i in ${tmp_args[@]}
do
    uniq_options=$uniq_options,${i}:
done
uniq_options=${uniq_options#*,}
C_Info "all_valid_options: $uniq_options"

#parse long options and save value
TEMP=`getopt -o "h" -l $uniq_options \
     -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"

C_Warn "CMDLINE: $@"
C_Warn "ARGUS:"
find=0
while true;
do
    find=0

    # --var1=value1 => __var_var1=value1
    for i in ${tmp_args[@]}
    do
        if [ "$1" = "--$i" ];then
            eval __var_$i="'$2'"
            var=`eval echo '$__var_'"$1"`
            echo "__var_$i=`eval echo '$__var_'$i`"
            shift 2
            find=1
            break
        fi
    done

    if [ $find -ne 0 ];then
        continue
    fi

    if [ "$1" = "-h" ];then
        copy_usage
        exit 0
    elif [ "$1" = "--" ];then
        shift
        break
    else
        echo "unknow option:$1 $2"
        exit 2
    fi
done
C_Warn "================================================================\n"

if [ $# -lt 1 ];then
    Error "not give the content index."
    exit 3
fi

if [ $1 -lt 0 -o $1 -ge $contents_num ];then
    Error "Error content index[$1]."
    exit 4
fi
index=$1

# get which content want to copy
last_content=${contents_array[$index]}
C_Info "choice the content[$index]: $last_content"

# replace <var> with value
replace_args=(${contents_args[$index]})
for i in ${replace_args[@]}
do
    if [ "$i" = "null" ];then
        continue
    fi

    value=`eval echo '$__var_'$i`

    if [ -z "$value" ];then
        Error "not give param[$i]'s value! \n\tgive $i's value like that: --$i=value "
        exit 5
    fi

    last_content=${last_content//<$i>/$value}
done

#copy content to clipboard
copy_func $last_content
statu=$?
if [ $statu -ne 0 ];then
    Error "Copy content to clipboard failed, exit status:$statu !"
    exit 6
fi

C_Debug ""
C_Debug "have copy the content[index=$index]:"
C_Info "$last_content"
C_Debug ""
C_Debug "Now paste the content with mouse middle or SHIFT+INSERT, ^_^"

exit 0

fi #if [ "${FUNCNAME[0]}" = "main" ];then

