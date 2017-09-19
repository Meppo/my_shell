#!/bin/bash

output=${output:=/dev/stdout}

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
export my_shell_ipc_path=$my_shell_ipc_path

logfile=${logfile:=/dev/stdout}
export logfile=$logfile

source $my_shell_ipc_path/log.sh

root_dir=$(cd `dirname $0`; pwd)
temp_sign_tool_dir=$root_dir/temp_sign_tool
official_sign_tool_dir=$root_dir/official_sign_tool

function usage()
{
    echo "Usage:"
    echo ""
    echo "  $0                                                          sign opk script"
    echo ""
    echo "  $0 sign_f [*.opk] [sign_tool_dir]                           sign opk directly via give the sign tool dir"
    echo "  $0 sign -i [tool_index] [*.opk]                             sign the opk with offical/temp sign tool"
    echo "  $0 sign [app_sign] [model] [app_center] [*.opk]             sign the opk with offical/temp sign tool"
    echo "  $0 add_tool -[ot] [app_sign] [model] [app_center] [sign_too.tar.gz]"
    echo "                                                              add offical/temp sign tool for opk"
    echo "  $0 del_tool -i [tool_index]                                 del offical/temp sign tool for opk"
    echo "  $0 list_tool                                                show sign tool list with [tool_index]"
    echo "  $0 help                                                     show this usage text"
    echo ""
    echo "e.g:"
    echo " 1) First add the temp sign tool for opk"
    echo "  $0 add_tool -t airlink_app P1 360 airlink_app_P1_360.tar.gz"
    echo ""
    echo " 2) Then show the opk list support sign"
    echo "  $0 list_tool"
    echo ""
    echo "  INDEX	APP_SIGN	MODEL	APP_CENTER	DIR"
    echo "  [Temp]"
    echo "  0	    airlink_app	P1	    360		    airlink_app_P1_360"
    echo ""
    echo " 3) sign the opk with sign tool index"
    echo "  $0 sign -i 0 /opk/path/airlink_app.opk"
    echo "  or "
    echo "  $0 sign airlink_app P1 360 /opk/path/airlink_app.opk"
    echo ""
    echo " Alternative, you can sign opk have compiled via give the sign tool dir directly,"
    echo "      this commond no need give the [tool_index] ."
    echo "  $0 sign_f airlink_app.opk /opt/sign_tool_dir/airlink_app_P1_360"
    echo ""
}

function check_and_mkdir()
{
    if [ ! -d "$1" ];then
        mkdir -p $1
        if [ ! -d "$1" ];then
            return 1
        fi
    fi

    return 0
}

offical_flag=0 #default sign with temp sign tool
tool_index=

#
# args:
#   $1: opk path
#   $2: sign tool directory
#
# return:
#   0: SUCCESS
#   >0: failed
#
function sign_opk_fast()
{
    local _opk_path=$1
    local _sign_tool_dir=$2

    if [ ! -f "$_opk_path" ];then
        Error "error opk path[$_opk_path]: not exist or not a regular file"
        return 1
    fi

    if [ ! -d "$_sign_tool_dir" -o ! -f "$_sign_tool_dir/make_sign.sh" ];then
        Error "error sign tool dir[$_sign_tool_dir]: not dir or make_sign.sh not exist."
        return 1
    fi

    # make_sign.sh need opk absolute path
    _opk_path=$(cd $(dirname $_opk_path); pwd)/$(basename $_opk_path)

    # do sign
    {
        cd $_sign_tool_dir \
            && chmod +x make_sign.sh \
            && ./make_sign.sh $_opk_path > $output 2>&1 &
    }  > $output 2>&1
    wait $!
    st=$?

    if [ $st -ne 0 ];then
        Error "sign [$_opk_path] with [$_sign_tool_dir] failed, exit status=$st."
    fi

    C_Info "sign [$_opk_path] with [$_sign_tool_dir] SUCCESS."
    return 0
}

# arr format: {appsign1, model, app_center, sign_tool_dir, temp/official_flag,
#              appsign2,  model, app_center, sign_tool_dir, temp/official_flag,
#               ...}
#
declare -a sign_tool_arr
arr_col=5
function get_sign_tool_list_array()
{
    local _app_sign=
    local _model=
    local _dir=
    local _res=
    local _root_search_dir=
    local _i=0
    local _j=0
    local _item=0

    _root_search_dir=$official_sign_tool_dir
    for _app_sign in `ls $_root_search_dir`
    do
        if [ ! -d "$_root_search_dir/$_app_sign" ];then
            continue;
        fi

        for _model in `ls "$_root_search_dir/$_app_sign"`
        do
            if [ ! -d "$_root_search_dir/$_app_sign/$_model" ];then
                continue;
            fi

            for _dir in `ls "$_root_search_dir/$_app_sign/$_model"`
            do
                if [ ! -d "$_root_search_dir/$_app_sign/$_model/$_dir" ];then
                    continue;
                fi

                _res=$(echo $_dir | grep -Eo '(netcore|360)')
                if [ -z "$res" ];then
                    _res=360
                fi

                _dir=$_root_search_dir/$_app_sign/$_model/$_dir
                sign_tool_arr[$_i]="$_app_sign $_model $_res $_dir 1"
                let _i++
            done
        done
    done

    _root_search_dir=$temp_sign_tool_dir
    for _app_sign in `ls $_root_search_dir`
    do
        if [ ! -d "$_root_search_dir/$_app_sign" ];then
            continue;
        fi

        for _model in `ls "$_root_search_dir/$_app_sign"`
        do
            if [ ! -d "$_root_search_dir/$_app_sign/$_model" ];then
                continue;
            fi

            for _dir in `ls "$_root_search_dir/$_app_sign/$_model"`
            do
                if [ ! -d "$_root_search_dir/$_app_sign/$_model/$_dir" ];then
                    continue;
                fi
                _res=$(echo $_dir | grep -Eo '(netcore|360)')
                if [ -z "$res" ];then
                    _res=360
                fi

                _dir=$_root_search_dir/$_app_sign/$_model/$_dir
                sign_tool_arr[$_i]="$_app_sign $_model $_res $_dir 0"
                let _i++
            done
        done
    done

    return 0
}

#
# args:
#    $1: appsign
#    $2: model
#    $3: app_center
#    $4: official_flag
#
# return value via args:
#    $5: sign tool directory
#
function get_sign_tool_path()
{
    local app_sign=$1
    local model=$2
    local app_center=$3
    local __official_flag=$4

    local __sign_tool_dir=$5

    local _app_sign=
    local _model=
    local _app_center=
    local _dir=
    local _flag=0
    local _item=
    local _i=

    get_sign_tool_list_array

    for _i in "${sign_tool_arr[@]}"
    do
        # arr format: {appsign1, model, app_center, sign_tool_dir, temp/official_flag}
        _item=($_i)

        _app_sign=${_item[0]}
        _model=${_item[1]}
        _app_center=${_item[2]}
        _dir=${_item[3]}
        _flag=${_item[4]}

        if [ "$app_sign" != "$_app_sign" \
            -o "$model" != "$_model" \
            -o "$app_center" != "$_app_center" \
            -o $__official_flag -ne $_flag \
            ];then
            continue
        fi

        C_Info "find sign tool dir[$(basename $_dir)] for appsign[$app_sign] model[$model] app_center[$app_center]"
        eval $__sign_tool_dir="'$_dir'"
        return 0
    done

    C_Info "Can't find sign tool dir for appsign[$app_sign] model[$model] app_center[$app_center]"

    return 1
}

#
# args:
#    $1: sign_tool_index
#
# return value via args:
#    $2: sign tool directory
#
function get_sign_tool_path_with_index()
{
    local _index=$1
    local _item=

    local __sign_tool_dir=$2

    if [ -z "$_index" ];then
        Error "Error index[$_index]."
        return 1
    fi

    get_sign_tool_list_array

    _item=(${sign_tool_arr[$_index]})
    if [ -z "$_item" ];then
        C_Info "Can't find sign tool dir according to the index[$_index]"
        return 2
    fi

    C_Info "find sign tool dir[$(basename ${_item[3]})] according to the index[$_index]"
    eval $__sign_tool_dir="'${_item[3]}'"

    return 0
}

#
# args:
# [OPTIONAL]:
#   need this args find sign tool when tool_index is null
#   $1: appsign
#   $2: model
#   $3: app_center
# [MUST]
#   $4: opk path
#
# return:
#   0: SUCCESS
#   >0: failed
#
function sign_opk()
{
    local _opk_path=
    local _app_sign=
    local _model=
    local _app_center=

    local _sign_tool_dir=

    if [ -n "$tool_index" ];then
        _opk_path=$1

        get_sign_tool_path_with_index $tool_index _sign_tool_dir
        if [ $? -ne 0 ];then
            Error "have no sign tool[index=$tool_index] to sign."
            return 1
        fi
    else
        _app_sign=$1
        _model=$2
        _app_center=$3
        _opk_path=$4

        if [ -z "$_app_sign" -o -z "$_model" -o -z "$_app_center" ];then
            Error "few argus to find sign tool: appsign[$_app_sign] model[$_model] app_center[$_app_center]."
            return 2
        fi
        get_sign_tool_path $_app_sign $_model $_app_center $official_flag _sign_tool_dir
    fi

    sign_opk_fast $_opk_path $_sign_tool_dir
    if [ $? -ne 0 ];then
        return 3
    fi

    return 0
}

function show_tool_list()
{
    local _app_sign=
    local _model=
    local _app_center=
    local _dir=
    local _flag=0
    local _item=
    local _i=
    local _index=0

    get_sign_tool_list_array

    C_Info "INDEX\tAPP_SIGN\tMODEL\tAPP_CENTER\tDIR\n"

    C_Info "[Official]"
    for _i in "${sign_tool_arr[@]}"
    do
        # arr format: {appsign1, model, app_center, sign_tool_dir, temp/official_flag}
        _item=($_i)

        _app_sign=${_item[0]}
        _model=${_item[1]}
        _app_center=${_item[2]}
        _dir=$(basename ${_item[3]})
        _flag=${_item[4]}

        if [ "$_flag" != "1" ];then
            let _index++
            continue
        fi

        C_Info "$_index\t$_app_sign\t$_model\t$_app_center\t\t$_dir"
        let _index++
    done
    C_Info ""

    C_Info "[Temp]"
    _index=0
    for _i in "${sign_tool_arr[@]}"
    do
        _item=($_i)
        _app_sign=${_item[0]}
        _model=${_item[1]}
        _app_center=${_item[2]}
        _dir=$(basename ${_item[3]})
        _flag=${_item[4]}

        if [ "$_flag" != "0" ];then
            let _index++
            continue
        fi

        C_Info "$_index\t$_app_sign\t$_model\t$_app_center\t\t$_dir"
        let _index++
    done
    C_Info ""

    return 0
}

#
# add/replace sign tool
# args:
#   $1: app_sign
#   $2: model
#   $3: app center
#   $4: sign tool *.tar.gz/directory
#
# return:
#   0: SUCCESS
#   >0: failed
#
function add_sign_tool()
{
    local _app_sign=$1
    local _model=$2
    local _app_center=$3
    local _sign_tool=$4
    local _tmp_dir=$root_dir/temp_sign_opk_dir_$$
    local _sign_tool_dir=
    local _last_sign_tool_dir=

    # null argus
    if [ -z "$_app_sign" -o -z "$_model" \
            -o -z "$_app_center" -o -z "$_sign_tool" ];then
        Error "few argus: app_sign:$_app_sign model:$_model app_center:$_app_center sign_tool:$_sign_tool"
        usage
        return 1
    fi

    # sign tool check
    if [ -f "$_sign_tool" ];then
        mkdir $_tmp_dir && tar -zxf $_sign_tool -C $_tmp_dir
        if [ $? -ne 0 ];then
            Error "extract sign_tool[$_sign_tool] failed."
            rm -rf $_tmp_dir
            return 2
        fi

        _sign_tool_dir=`find $_tmp_dir -name "make_sign.sh" | xargs dirname`
        if [ $? -ne 0 ];then
            Error "Error sign_tool[$_sign_tool]: can't find the script make_sign.sh..."
            rm -rf $_tmp_dir
            return 3
        fi
    elif [ -d "$_sign_tool" ];then

        _sign_tool_dir=`find $_sign_tool -maxdepth 1 -name "make_sign.sh" | xargs dirname`
        if [ $? -ne 0 ];then
            Error "Error sign_tool[$_sign_tool]: can't find the script make_sign.sh..."
            rm -rf $_tmp_dir
            return 3
        fi

        cp -rf $_sign_tool $_tmp_dir
        _sign_tool_dir=$_tmp_dir
    else
        Error "Error sign_tool[$_sign_tool]: not exist or is not dir."
        return 3
    fi

    if [ $offical_flag -ne 0 ];then
        _last_sign_tool_dir=$official_sign_tool_dir/$_app_sign/$_model/${_app_sign}_${_model}_${_app_center}
    else
        _last_sign_tool_dir=$temp_sign_tool_dir/$_app_sign/$_model/${_app_sign}_${_model}_${_app_center}
    fi

    if [ -d "$_last_sign_tool_dir" ];then
        rm -rf $_last_sign_tool_dir
        C_Info "del old [$_last_sign_tool_dir] first."
    fi

    mkdir -p `dirname $_last_sign_tool_dir` && mv $_sign_tool_dir $_last_sign_tool_dir
    if [ $? -ne 0 ];then
        Error "mv [$_sign_tool] to [$_last_sign_tool_dir] failed..."
        rm -rf $_tmp_dir
        return 4
    fi
    rm -rf $_tmp_dir

    C_Info "add sign tool for app_sign[$_app_sign] model[$_model] app_center[$_app_center] => $_last_sign_tool_dir SUCCESS."

    C_Info "\nshow list after add:\n"
    show_tool_list
    return 0
}

# del sign tool
#
# return:
#   0: success
#   >0: failed
#
function del_sign_tool()
{
    local _sign_tool_dir=
    local _res=

    get_sign_tool_path_with_index $tool_index _sign_tool_dir
    if [ $? -ne 0 ];then
        Error "have no sign tool[index=$tool_index] to del."
        return 1
    fi
    unset sign_tool_arr[$tool_index]

    if [ -d "$_sign_tool_dir" ];then
        C_Info "del dir[$_sign_tool_dir] according to the sign tool index[$tool_index]."
        rm -rf $_sign_tool_dir
    else
        C_Info "no dir[$_sign_tool_dir] to del according to the sign tool index[$tool_index]."
    fi

    # dir format: /path/temp_sign_dir/[app_sign]/[model]/[last_dir_name]
    # del empty model dir
    _sign_tool_dir=$(dirname $_sign_tool_dir)
    _res=$(ls $_sign_tool_dir)
    if [ -z "$_res" ];then
        C_Info "del empty dir[$_sign_tool_dir]..."
        rm -rf $_sign_tool_dir


        # del empty app_sign dir
        _sign_tool_dir=$(dirname $_sign_tool_dir)
        _res=$(ls $_sign_tool_dir)
        if [ -z "$_res" ];then
            C_Info "del empty dir[$_sign_tool_dir]..."
            rm -rf $_sign_tool_dir
        fi
    fi

    C_Info "\nshow list after del:\n"
    show_tool_list
    return 0
}

# do things we need to do when excute this script directly,not source this script.
#   if source this script by other scripts, FUNCNAME[]: source main
if [ "${FUNCNAME[0]}" = "main" ];then

TEMP=`getopt  -o "qothi:" -l help -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"
C_Warn "CMDLINE: $@"
C_Warn "ARGUS:"
while true ; do
        case "$1" in
                -h|--help)
                    usage
                    exit 0
                    ;;
                -i)
                    tool_index=$2
                    C_Debug "\tuse sign tool[index=$tool_index]"
                    shift 2
                    ;;
                -q) 
                    quiet_mode=1
                    output=/dev/null
                    C_Debug "\tquiet_mode: $quiet_mode output=$output"
                    shift 1
                    ;;
                -o)
                    offical_flag=1
                    C_Debug "\twith official sign tool"
                    shift 1
                    ;;
                -t)
                    offical_flag=0
                    C_Debug "\twith temp sign tool"
                    shift 1
                    ;;
                --)
                    shift
                    break ;;
                *)
                    echo "Unknow option: $1 $2"
                    exit 1 ;;
        esac
done
C_Warn "================================================================\n"

Debug "args: $@ "

if [ "$1" = "sign" ];then
    shift 1
    if [ $# -lt 1 ];then
        Error "too few args for cmd[sign]: $@ "
        usage
        exit 1
    fi
    sign_opk $@
elif [ "$1" = "add_tool" ];then
    shift 1
    if [ $# -lt 4 ];then
        Error "too few args for cmd[add_tool]: $@ "
        usage
        exit 1
    fi
    add_sign_tool $@
elif [ "$1" = "del_tool" ];then
    shift 1
    del_sign_tool $@
elif [ "$1" = "list_tool" ];then
    shift 1
    show_tool_list
elif [ "$1" = "sign_f" ];then
    shift 1
    if [ $# -lt 2 ];then
        Error "too few args for cmd[sign_f]: $@ "
        usage
        exit 1
    fi
    sign_opk_fast $@
elif [ "$1" = "help" ];then
    usage
else
    Error "error cmd[$1] ..."
    usage
    exit 2
fi

exit 0

fi #if [ "${FUNCNAME[0]}" = "main" ];then
