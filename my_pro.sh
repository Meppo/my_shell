#!/bin/bash

my_shell_ipc_path=/opt/work/my_script/shell_ipc

quiet_mode=0

source $my_shell_ipc_path/log.sh
source $my_shell_ipc_path/bar.sh

output=/dev/stdout
logfile=/dev/stdout

# export var to child script
export output
export logfile

# module script file rule:
#  <module_name>.sh
#   - <module_name>_usage()
module_array=(
    "test"
    "copy"
)
module_num=${#module_array[@]}

# source all module scripts
for i in ${module_array[*]}
do
    source ${i}.sh
done

function show_all_module_usage()
{
    local i=

    C_Info "This is ywj's project handy script, include this module:"

    for i in ${module_array[*]}
    do
        echo "module ${i}:"
        eval ${i}_usage 
        echo ""
    done

    C_Info "All modules list:"
    i=0
    while [ $i -lt $module_num ]
    do
        echo -e "\t$i : ${module_array[$i]}"
        let i++
    done
}

function show_user_method_use_module()
{
    echo ""
    C_Info "You can use module like this:"
    echo -e "\t$0 0 arg1 arg2"
    echo -e "\t  or"
    echo -e "\t$0 test arg1 arg2"
    echo -e "\t  mean excute test module script with argus(arg1, arg2)"
}

function get_module_id_by_arg()
{
    local str=$1
    local __module_id=$2
    local i=0

    if [ -z "$1" -o -z "$2" ];then
        Error "Argus error, arg1[$1], arg2[$2]..."
        return 1
    fi

    while [ $i -lt $module_num ]
    do
        if [ "$str" = "${module_array[$i]}" ];then
            eval $__module_id="'$i'"
            return 0
        fi

        if [ $str -eq $i ];then
            eval $__module_id="'$i'"
            return 0
        fi
        let i++
    done

    Error "Can't find the module by arg[$1]."
    return 1
}

if [ $# -lt 1 ];then
    show_all_module_usage
    show_user_method_use_module
    exit 0
fi

choice_module_id=
get_module_id_by_arg $1 choice_module_id
if [ $? -ne 0 ];then
    exit 1
fi

shift 1
C_Info "Execute module cmd: ./${module_array[$choice_module_id]}.sh $*"
echo ""

sh ${module_array[$choice_module_id]}.sh $*
statu=$?
if [ $statu -ne 0 ];then
    Error "Execute ${module_array[$choice_module_id]}.sh failed, exit status:$statu !"
fi
