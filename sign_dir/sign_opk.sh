#!/bin/bash

output=/dev/stdout
logfile=/dev/stdout

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
    echo "  $0                                                          compile/sign opk script"
    echo ""
    echo "  $0 sign_f [*.opk] [sign_tool_dir]                           sign opk directly via give the sign tool dir"
    echo "  $0 sign -[ot] [app_sign] [model] [app_center] [*.opk]       sign the opk with offical/temp sign tool"
    echo "  $0 comp [app_sign] [model list...]                          compile the opk"
    echo "  $0 comp_sign -[ot] [app_sign] [model] [app_center]          compile opk then sign with offical/temp sign tool"
    echo "  $0 add_tool -[ot] [app_sign] [model] [app_center] [sign_too.tar.gz]"
    echo "                                                              add offical/temp sign tool for opk"
    echo "  $0 del_tool -[ot] [app_sign] [model] [app_center]           del offical/temp sign tool for opk"
    echo "  $0 list_tool                                                show opk list support sign"
    echo "  $0 help                                                     show this usage text"
    echo ""
    echo "e.g:"
    echo " 1) First add the temp sign tool for opk"
    echo "  $0 add_tool -t airlink_app P1 360 airlink_app_P1_360.tar.gz"
    echo ""
    echo " 2) Then show the opk list support sign"
    echo "  $0 list_tool"
    echo ""
    echo " 3) Comp and sign the opk with temp sign tool"
    echo "  $0 comp_sign -t airlink_app P1"
    echo ""
    echo " Of course, you can sign opk have compiled directly with sign tool have support."
    echo "  $0 sign -t airlink_app P1 360 airlink_app.opk"
    echo ""
    echo " Alternative, you can sign opk have compiled via give the sign tool dir directly,"
    echo "      this commond no need give the [app_sign] [model] [app_center]."
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

TEMP=`getopt  -o "qoth" -l help -n "$0" -- "$@"`

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

#
# args:
#    $1: appsign
#    $2: model
#    $3: app_center
# return value with args:
#    $4: sign tool directory
#
function get_sign_tool_path()
{
    local app_sign=$1
    local model=$2
    local app_center=$3

    local __sign_tool_dir=$4

    local _app_sign=
    local _model=
    local _dir=
    local _res=
    local _root_search_dir=

    if [ $offical_flag -ne 0 ];then
        _root_search_dir=$official_sign_tool_dir
    else
        _root_search_dir=$temp_sign_tool_dir
    fi

    # sign tool directory rule:
    #       sign_too_root_dir/app_sign/model/${app_sign}_${model}_${app_center}
    # 
    # begin match: app_sign
    for _app_sign in `ls $_root_search_dir`
    do
        if [ "$_app_sign" != "$app_sign" ];then
            continue
        fi

        if [ ! -d "$_root_search_dir/$_app_sign" ];then
            continue;
        fi

        # match: model
        for _model in `ls "$_root_search_dir/$_app_sign"`
        do
            if [ "$model" != "$_model" ];then
                continue
            fi

            if [ ! -d "$_root_search_dir/$_app_sign/$_model" ];then
                continue;
            fi

            # find dir: ${app_sign}_${model}_${app_center}
            for _dir in `ls "$_root_search_dir/$_app_sign/$_model"`
            do
                if [ ! -d "$_root_search_dir/$_app_sign/$_model/$_dir" ];then
                    continue;
                fi
                _dir=$(basename $_dir)

                res=$(echo $_dir | grep -Eo "$app_center")
                if [ -n "$res" ];then
                    C_Info "find sign tool dir[$_dir] for appsign[$app_sign] model[$model] app_center[$app_center]"
                    eval $__sign_tool_dir="'$_root_search_dir/$_app_sign/$_model/$_dir'"
                    return 0
                else
                    C_Info "Can't find sign tool dir[$_dir] for appsign[$appsign] model[$model] app_center[$app_center]"
                fi
            done
        done
    done

    return 1
}

#
# args:
#   $1: app_sign
#   $2: model
#   $3: opk path
#
# return:
#   0: SUCCESS
#   >0: failed
#
function sign_opk()
{
    local _app_sign=$1
    local _model=$2
    local _app_center=$3
    local _opk_path=$4
    local _sign_tool_dir=

    # null argus
    if [ -z "$_app_sign" -o -z "$_model" \
            -o -z "$_app_center" -o -z "$_opk_path" ];then
        Error "few argus: app_sign:$_app_sign model:$_model app_center:$_app_center _opk_path:$_opk_path"
        usage
        return 1
    fi

    if [ ! -f "$_opk_path" ];then
        Error "error opk path[$_opk_path]: not exist or not a regular file"
        return 2
    fi

    get_sign_tool_path $_app_sign $_model $_app_center _sign_tool_dir
    if [ $? -ne 0 ];then
        Error "have no sign tool to sign  app_sign:$_app_sign model:$_model app_center:$_app_center _opk_path:$_opk_path ..."
        return 3
    fi

    sign_opk_fast $_opk_path $_sign_tool_dir
    if [ $? -ne 0 ];then
        return 4
    fi

    return 0
}

function show_tool_list()
{
    local _app_sign=
    local _model=
    local _dir=
    local _res=
    local _root_search_dir=

    C_Info "APP_SIGN\tMODEL\tAPP_CENTER\tDIR\n"

    C_Info "[Official]"
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
                _dir=$(basename $_dir)

                res=$(echo $_dir | grep -Eo '(netcore|360)')
                if [ -z "$res" ];then
                    C_Info "$_app_sign\t$_model\t360\t\t$_dir"
                else
                    C_Info "$_app_sign\t$_model\t360\t\t$_dir"
                fi
            done
        done
    done
    C_Info ""

    C_Info "[Temp]"
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
                _dir=$(basename $_dir)

                res=$(echo $_dir | grep -Eo '(netcore|360)')
                if [ -z "$res" ];then
                    C_Info "$_app_sign\t$_model\t360\t\t$_dir"
                else
                    C_Info "$_app_sign\t$_model\t360\t\t$_dir"
                fi
            done
        done
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
    return 0
}

# del sign tool
# args:
#   $1: app_sign
#   $1: model
#   $2: app_center
# return:
#   0: success
#   >0: failed
#
function del_sign_tool()
{
    local _app_sign=$1
    local _model=$2
    local _app_center=$3
    local _last_sign_tool_dir=
    local res=

    if [ -z "$_app_sign" ];then
        Error "app_sign is null"
        usage
        return 1
    fi

    if [ $offical_flag -ne 0 ];then
        _last_sign_tool_dir=$official_sign_tool_dir
    else
        _last_sign_tool_dir=$temp_sign_tool_dir
    fi

    if [ -z "$_model" ];then
        _last_sign_tool_dir=$_last_sign_tool_dir/$_app_sign
    else
        if [ -z "$_app_center" ];then
            _last_sign_tool_dir=$_last_sign_tool_dir/$_app_sign/$_model
        else
            _last_sign_tool_dir=$_last_sign_tool_dir/$_app_sign/$_model/${_app_sign}_${_model}_${_app_center}
        fi
    fi

    if [ -d "$_last_sign_tool_dir" ];then
        C_Info "del dir[$_last_sign_tool_dir] for appsign[$_app_sign] model[$_model] app_center[$_app_center]."
        rm -rf $_last_sign_tool_dir
    else
        C_Info "no dir[$_last_sign_tool_dir] to del for appsign[$_app_sign] model[$_model] app_center[$_app_center]."
    fi

    if [ -n "$_app_center" ];then
        _last_sign_tool_dir=$(dirname $_last_sign_tool_dir)
        res=$(ls $_last_sign_tool_dir)

        # empty dir, del this dir
        if [ -z "$res" ];then
            C_Info "del empty dir[$_last_sign_tool_dir] for app_sign[$_app_sign] model[$_model]..."
            rm -rf $_last_sign_tool_dir
        fi
    fi

    if [ -n "$_model" ];then
        _last_sign_tool_dir=$(dirname $_last_sign_tool_dir)
        res=$(ls $_last_sign_tool_dir)

        # empty dir, del this dir
        if [ -z "$res" ];then
            C_Info "del empty dir[$_last_sign_tool_dir] for app_sign[$_app_sign] model[$_model]..."
            rm -rf $_last_sign_tool_dir
        fi
    fi

    return 0
}



#    echo "  $0 sign -[ot] [app_sign] [model] [*.opk]                    sign the opk with offical/temp sign tool"
#    echo "  $0 comp [app_sign] [model list...]                          compile the opk"
#    echo "  $0 comp_sign -[ot] [app_sign] [model]                       compile opk then sign with offical/temp sign tool"
#    echo "  $0 add_tool -[ot] [app_sign] [model] [sign_too.tar.gz]      add offical/temp sign tool for opk"
#    echo "  $0 del_tool -[ot] [app_sign] [model]                        del offical/temp sign tool for opk"
#    echo "  $0 list_tool                             
if [ "$1" = "sign" ];then
    shift 1
    if [ $# -lt 4 ];then
        Error "too few args for cmd[sign]: $@ "
        usage
        exit 1
    fi
    sign_opk $@
elif [ "$1" = "com" ];then
    Debug "compile"
elif [ "$1" = "comp_sign" ];then
    Debug "compile sign"
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
    if [ $# -lt 1 ];then
        Error "too few args for cmd[del_tool]: $@ "
        usage
        exit 1
    fi
    del_sign_tool $@
elif [ "$1" = "list_tool" ];then
    shift 1
    show_tool_list $@
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

if [ $temp_sign -ne 0 -a -z "$temp_sign_dir" ];then
    Error "Need give the temp_sign_dir with option: --temp-sign-dir "
    usage
    exit 1
fi

if [ $# -lt 2 ];then
    Error "few args..."
    usage
    exit 1
fi

opk_name=$1
shift 1
project_list=($*)

if [ -z "$dst_path" ];then
    if ! check_and_mkdir $DEF_DST_PATH ;then
        Error "error default dst path[$DEF_DST_PATH]."
        exit 1
    fi
    dst_path=$DEF_DST_PATH
fi

if [ $temp_sign -eq 0 ];then
    C_Warn "Will compile [$opk_name] for projects[$project_list], copy to dir [$dst_path]."
else
    C_Warn "Will compile [$opk_name] and sign with temp key[--temp-sign] for projects[$project_list], copy to dir [$dst_path]."
fi

function clean_dstpath()
{
    Debug "clean dst path[${dst_path}] ..."
    if [ -d "${dst_path}" ];then
        rm -rf ${dst_path}/*
    fi
}

# args: 
#   arg1: project name
#   arg2: opk name
#   arg3: output app_dir_path var name
#   arg4: output env_path var name
function get_project_path()
{
    local __appdirpath_var=$3
    local __envpath_var=$4
    local projects_value_arr=

    # get special project path from the arr spe_projects[]
    for key in $(echo ${!spe_projects[*]})
    do
        if [ "$key" = "$1" ];then
            projects_value_arr=(${spe_projects[$key]})
            #Debug "find special project ${key} : ${projects_value_arr[@]}"
            eval $__appdirpath_var="'${projects_value_arr[0]}'"
            eval $__envpath_var="'${projects_value_arr[1]}'"
            return 0;
        fi
    done

    # project: P0  => N360_P0
    # project: N1  => N360_N1
    eval $__appdirpath_var="'${work_path}/N360_$1/user/app'"
    eval $__envpath_var="'${work_path}/N360_$1/user/make.sh'"

    return 0;

}

# args:
#   arg1: project name
#   arg2: opk name
#   arg3: output opk_dir var name
#   arg4: output app_sign var name
#   arg5: output opk_name var name
function get_opk_name()
{
    local __opkdir_var=$3
    local __appsign_var=$4
    local __opkname_var=$5
    local opk_value_arr=

    for key in $(echo ${!spe_opk[*]})
    do
        if [ "$key" = "$2" ];then
            opk_value_arr=(${spe_opk[$key]})
            #Debug "find special opk ${key} : ${opk_value_arr[@]}"
            eval $__opkdir_var="'${opk_value_arr[0]}'"
            eval $__appsign_var="'${opk_value_arr[1]}'"
            eval $__opkname_var="'${opk_value_arr[2]}'"
            return 0;
        fi
    done

    eval $__opkdir_var="'$2'"
    eval $__appsign_var="'$2'"
    eval $__opkname_var="'$2'"

    return 0;
}

# args:
#   arg1: project name
#   arg2: opk name
#   arg3: last opk path
function do_temp_sign()
{
    local opk_name=
    local app_sign=
    local opk_dir=
    local app_dir_path=
    local env_path=

    local st=

    if [ -z "$1" -o -z "$2" -o -z "$3" ];then
        Error "project_name[$1] or opk_name[$2] or opk_path[$3] is null!"
        return -1
    fi

    # get all path we need for compile opk
    # e.g: multi_pppd P0
    #   opk_dir: multi_pppd
    #   appsign: multi_pppd
    #   opk_name: multidial
    get_opk_name $1 $2 opk_dir app_sign opk_name 
    Debug "get opk dir=${opk_dir} name=${opk_name}"

    # generate sign script path
    last_sign_dir=${temp_sign_dir}/${app_sign}/${app_sign}_$1/
    Debug "get last sign dir=${last_sign_dir} dst_opk=$3"

    # do temp sign
    {
        cd ${last_sign_dir} \
            && chmod +x make_sign.sh \
            && ./make_sign.sh $3 > $output 2>&1 &
    }  > $output 2>&1
    wait $!
    st=$?

    if [ $st -ne 0 ];then
        Error "temp sign $3 for $1 failed, exit status=$st."
    fi

    return $st
}


# args: 
#   arg1: project name
#   arg2: opk name
function compile_opk()
{
    local opk_name=
    local app_sign=
    local opk_dir=
    local app_dir_path=
    local env_path=

    local dst_opk_name=
    local st=

    if [ -z "$1" -o -z "$2" ];then
        Error "project_name[$1] or opk_name[$2] is null!"
        return -1
    fi

    # get all path we need for compile opk
    # e.g: multi_pppd P0
    #   opk_dir: multi_pppd
    #   appsign: multi_pppd
    #   opk_name: multidial
    #   app_dir_path: /opt/work/N360/N360_P0/user/app/
    #   env_path: /opt/work/N360/N360_P0/user/make.sh
    get_opk_name $1 $2 opk_dir app_sign opk_name 
    Debug "get opk dir=${opk_dir} name=${opk_name}"

    get_project_path $1 $2 app_dir_path env_path
    Debug "get app dir path=${app_dir_path} env_path=${env_path}"

    if [ $temp_sign -ne 0 ];then
        dst_opk_name=${dst_path}/${opk_name}_${1}_TempSign_${dst_prefix}.opk
    else
        dst_opk_name=${dst_path}/${opk_name}_${1}_${dst_prefix}.opk
    fi
    dst_json_name=${dst_path}/${opk_name}_${1}_${dst_prefix}.json

    Debug "dst_opk_name=${dst_opk_name} dj=${dst_json_name} opk_name=${opk_name}"
    # compile opk
    {
        cd `dirname ${env_path}` \
            && source ${env_path} `dirname ${env_path}` \
            && echo "userdir=$USERDIR"\
            && cd ${app_dir_path}/${opk_dir}\
            && make clean && make $make_args \
            && if test -f ${opk_name}.opk; then cp ${opk_name}.opk ${dst_opk_name} ;\
                cp app.json ${dst_json_name}; fi & 
    }  > $output 2>&1
    wait $!
    st=$?

    if [ $st -ne 0 ];then
        Error "Compile $2 for $1 failed, exit st=$st."
        return $st
    fi

    if [ $temp_sign -eq 0 ];then
        return 0
    fi

    # do temp sign
    do_temp_sign $1 $2 ${dst_opk_name}
    st=$?
    if [ $st -ne 0 ] ;then
        Error "temp sign ${dst_opk_name} for $1 failed, exit status=$st."
    fi

    return $st
}

clean_dstpath

for p in ${project_list[@]}
do
    Debug "Begin compile ${opk_name} for ${p} ..."

    compile_opk ${p} ${opk_name}
    if [ $? -eq 0 ] ;then
        Info "compile ${opk_name} for ${p} SUCCESS."
    else
        Error "compile ${opk_name} for ${p} FAILED."
    fi
done

Info "Compile finished. get all opks in dir ${dst_path} ..."
