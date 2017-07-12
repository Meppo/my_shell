#!/bin/bash

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
logfile=${logfile:=/dev/stdout}
source $my_shell_ipc_path/log.sh

content_file_path=/opt/work/exchange_dir/copy.txt
exit_no=1

contents_array=(
    "This is test content, you can use option --arg1 replace <arg1> --arg2 replace <arg2> , try it!"
)

contents_args=(
    "arg1 arg2"
)

contents_num=${#contents_array[@]}

function read_history_contents_from_file()
{
    local line
    local args

    if [ ! -f "$content_file_path" ];then
        return 0
    fi

    while read line 
    do
        if [ -z "$line" ];then
            continue
        fi

        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        contents_array+=("$line")

        args=`echo "$line" | grep '<\([^<>]*\)>' -o  | tr '<>\n' ' '`
        if [ -z "$args" ];then
            args="null"
        fi
        contents_args+=("$args")
    done < $content_file_path

    contents_num=${#contents_array[@]}
}

function save_content_to_file()
{
    new_line=$1
    tmp_array=

    if [ -z "$new_line" ];then
        return 0
    fi

    if [ ! -f "$content_file_path" ];then
        echo '' > $content_file_path
        if [ ! -f "$content_file_path" ];then
            Error "create file $content_file_path failed"
            return 1
        fi
    fi

    #del extra space at tail
    new_line=`echo "$new_line" | sed 's/^ *//g ; s/ *$//g'`

    while read line 
    do
        if [ -z "$line" ];then
            continue
        fi

        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        if [ "$new_line" = "$line" ];then
            Debug "have exist, no need save again."
            return 0
        fi

        tmp_array+=("$line")
    done < $content_file_path

    echo "" >> $content_file_path
    echo "$new_line" >> $content_file_path
}

function del_content_from_file()
{
    local new_line=$1
    local str

    if [ -z "$new_line" -o  ! -f "$content_file_path" ];then
        return 0
    fi

    # del the content
    str="sed -i '/^$new_line$/d' $content_file_path"
    eval $str

    #del duplicate null line
    sed -i '/^$/{N ; /^\n$/D}' $content_file_path
    return $?
}


function copy_usage()
{
    echo "NAME:"
    echo "  $0 [index] [options]"
    echo ""
    echo "DESCRIPTION:"
    echo " the script used to copy the data with [index] to clipboard, "
    echo "      then you can paste the content whit middle mouse or SHIFT+INSERT."
    echo ""
    echo "Index-Content list:"
    echo "  read content list from the file copy.txt, you can use option -a/-d add/del the content."
    echo ""
    local i=0
    while [ $i -lt $contents_num ]
    do
        echo "  $i: ${contents_array[$i]}"
        if [ "${contents_args[$i]}" != "null" ];then
            echo "      args: ${contents_args[$i]}"
        fi
        let i++
    done
    echo ""
    echo "OPTIONS:"
    echo "  -a <content>: add new content to file[copy.txt], you can copy it with index after add ."
    echo "  -d <content>: del content from file[copy.txt]"
    echo ""
    echo "  some sentences need change special param with options:"
    echo "  --ip=<value>"
    echo "     some sentences need ip. will use the <value> replace <ip> "
    echo "  --mac=<value>"
    echo "  --app=<value>"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 0 --arg1=test_value1 --arg2=test_value2"
    echo "   then you can paste the content with middle mouse or SHIFT+INSERT: "
    echo "     This is test content, you can use option --arg1 replace test_value1 --arg2 replace test_value2 , try it!"
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

read_history_contents_from_file

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
TEMP=`getopt -o "ha:d:" -l $uniq_options \
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
    elif [ "$1" = "-a" ];then

        save_content_to_file "$2"
        statu=$?
        if [ $statu -ne 0 ];then
            Error "Save content to $content_file_path failed, exit status:$statu !"
            exit 6
        fi
        Info "Save content to $content_file_path success."
        exit 0
        break
    elif [ "$1" = "-d" ];then
        if [ $2 -lt 0 -o $2 -ge $contents_num ];then
            Error "Error content index[$2]."

            exit $exit_no
            let exit_no++
        fi

        del_content_from_file "${contents_array[$2]}"
        statu=$?
        if [ $statu -ne 0 ];then
            Error "Del content from $content_file_path failed, exit status:$statu !"

            exit $exit_no
            let exit_no++
        fi
        Info "Del content[index=$2] from $content_file_path success."
        exit 0
        break
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

