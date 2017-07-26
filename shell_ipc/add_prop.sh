#!/bin/sh

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
logfile=${logfile:=/dev/stdout}
source $my_shell_ipc_path/log.sh

add_prop()
{
    local my_dir=$1
    local prop_name=$2
    local prop_value=$3
    local origin_value=

    cd $my_dir
    if [ $? -ne 0 ];then
        Error "cd $sub_dir failed."
        exit 2
    fi

    if [ -z "$prop_name" -o -z "$prop_value" ];then
        Error "null args: prop_name[$prop_name], prop_value[$prop_value]"
        exit 2
    fi

    origin_value=`svn propget $prop_name`
    if [ "$origin_value" = "$prop_value" ];then
        Debug "have set the $prop_name=$prop_value, no need set again!"
        cd ..
        return 0
    fi

    svn propset $prop_name "$prop_value" .
    if [ $? -eq 0 ];then
        echo "add prop $prop_name = $prop_value to $my_dir success."
        svn ci . -m "add prop $prop_name = $prop_value"
    else
        echo "add prop $prop_name = $prop_value to $my_dir failed"
    fi
    cd ..
}

co_multi_dir()
{
    local file=$1
    while read sub_dir
    do
        echo "co $sub_dir ..."
        svn co $sub_dir --depth immediates
    done < $file
}

# do things we need to do when excute this script directly,not source this script.
#   if source this script by other scripts, FUNCNAME[]: source main
if [ "${FUNCNAME[0]}" = "main" ];then

usage()
{
    echo "Usage:"
    echo "  $0 [options] [dir] [prop_name] [prop_value]"
    echo ""
    echo " Options:"
    echo "   -q: quiet mode"
    echo ""
    echo "  e.g:"
    echo "   $0 N360_P1 Release_time \"2017-07-25 16:25\""
    echo " "
}

TEMP=`getopt  -o "q" -n "$0" -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"
C_Warn "CMDLINE: $@"
C_Warn "ARGUS:"
while true ; do
        case "$1" in
                -q) 
                    quiet_mode=1
                    output=/dev/null
                    C_Debug "\tquiet_mode: $quiet_mode output=$output"
                    shift 1;;
                --)
                    shift
                    break ;;
                *)
                    echo "Unknow option: $1 $2"
                    exit 1 ;;
        esac
done
C_Warn "================================================================\n"

if [ $# -lt 3 ];then
    Error "too few argus..."
    usage
    exit 1
fi

if [ ! -d "$1" ];then
    Error "$1 is not dir!"
    usage
    exit 2;
fi


echo "add prop for dir[$1]!"
add_prop $1 $2 $3

exit 0

fi #if [ "${FUNCNAME[0]}" = "main" ];then
