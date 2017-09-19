#!/bin/bash


output=/dev/null
export output=$output

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
export my_shell_ipc_path=$my_shell_ipc_path

logfile=${logfile:=/dev/stdout}
export logfile=$logfile
source $my_shell_ipc_path/log.sh

root_dir=$(cd `dirname $0`; pwd)
compile_script=$root_dir/compile_opk.sh
sign_script=$root_dir/sign_opk.sh

dst_path=$root_dir/target
dst_prefix=${dst_prefix:=`date "+%Y%m%d_%H%M"`}

# app_sign model
target_arr=(\
    "airlink_app P0 " \
    "multi_pppd P1" \
)
# args for make
make_args_arr=(\
    "" \
    "" \
)
# app_sign model app_center official_flag
sign_arr=(\
    "airlink_app P0 360 0" \
    "multi_pppd P1 360 0" \
)

source $compile_script
source $sign_script

function do_task()
{
    local _i=
    local _item=
    local _app_sign=
    local _model=
    local _official_flag=
    local _dst_opk_name=

    local _index=0
    local _res=
    local _sign_tool_dir=

    rm -rf $dst_path/*

    for _i in "${target_arr[@]}"
    do
        # compile opk
        C_Warn "Begin compile opk: $_i ..."
        compile_opk $_i "${make_args_arr[$_index]}" $dst_path _res
        if [ $? -ne 0 ];then
            return 1
        fi
        _item=($_i)
        _app_sign=${_item[0]}
        _model=${_item[1]}

        if [ -z "${sign_arr[$_index]}" ];then
            Warn "no sign info to sign opk[$_res]"
            let _index++
            continue
        fi

        # sign opk
        C_Warn "\nBegin sign opk: $_res sign_args: ${sign_arr[$_index]}..."
        _sign_tool_dir=
        get_sign_tool_path ${sign_arr[$_index]} _sign_tool_dir
        sign_opk_fast $_res $_sign_tool_dir
        if [ $? -ne 0 ];then
            return 1
        fi
        _item=(${sign_arr[$_index]})
        _official_flag=${_item[3]}

        if [ "$_official_flag" = "0" ];then
            _dst_opk_name=${dst_path}/${_app_sign}_${_model}_TempSign_${dst_prefix}.opk
        else
            _dst_opk_name=${dst_path}/${_app_sign}_${_model}_Sign_${dst_prefix}.opk
        fi
        mv $_res $_dst_opk_name

        C_Debug "compile and sign opk result => $_dst_opk_name \n"

        let _index++
    done
}

do_task

