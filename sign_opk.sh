#!/bin/bash

my_shell_ipc_path=/opt/work/my_script/shell_ipc
source $my_shell_ipc_path/log.sh
source $my_shell_ipc_path/bar.sh

work_path=/opt/work/N360
temp_sign=0
temp_sign_dir=
dst_path=
make_args=
quiet_mode=0
output=/dev/stdout
logfile=/dev/stdout

# dest file name prefix:
#   e.g: /opt/work/exchange_dir/opk_dir/airlink_app_P1_20170621_1111.opk
dst_prefix=`date "+%Y%m%d_%k%M"`
DEF_DST_PATH=/opt/work/exchange_dir/opk_dir

function usage()
{
    echo "Usage: ./opk_sign [options] [opk_name] [project_list...]"
    echo "Options:"
    echo "  -q: [no arg]quiet mode"
    echo "  --temp-sign: [no arg]sign the opk with temp key"
    echo "  --temp-sign-dir: the dir contain all temp keys"
    echo "      sign_dir generation rule: tmp-sign-dir/[opk_name]/[opk_name]_[project_name]/ "
    echo "      e.g: /tmp/opk_sign/airlink_app/airlink_app_P1/ "
    echo "  --dst-path: the path restore the opk after compiled"
    echo "  --make-args: compile extra arguments "
    echo "e.g:"
    echo "  ./opk_sign airlink_app P0 P1 P2 P3 P4 "
    echo "  ./opk_sign --temp-sign --make-args='CC=mips-linux-gcc install' airlink_app P0 P1 --dst-path=/tmp/opk_dir"
}

# opk default name rule:
#   opk_name  dir_name=opk_name app_sign=opk_name opk_name=opk_name
# e.g:
#   opk_name: airlink_app  dir_name: airlink_app  opk_name: airlink_app
#
# special name for some opk
declare -A spe_opk
spe_opk=(
    #[name]="dir_name  app_sign opk_name"
    [multi_pppd]="multi_pppd multi_pppd multidial"
    #airlink_app: default name rule
)

# project default path rule: 
#   project_name  path=/opt/work/N360/N360_[project_name]/user/app/ env_script=/opt/work/N360/N360_[project_name]/user/make.sh
# e.g: 
#   project_name: P2  path=/opt/work/N360/N360_P2/user/app env_script=/opt/work/N360/N360_P2/user/make.sh
#
# special path dict for some project
declare -A spe_projects
spe_projects=(
    #[project_name]="app_dir_path  env_script_path"
    #P0:default path rule
    [P1]="${work_path}/N360_TRUNK/user/app ${work_path}/N360_TRUNK/env.sh"
    #P2:default path rule
    #P3:default path rule
    #P4:default path rule
    [POWER4S_P0]="${work_path}/N360_P0_NETCORE/user/app ${work_path}/N360_P0_NETCORE/user/make.sh"
    #N1:default path rule
    [CTC_P1]="${work_path}/N360_BRANCH/user/app ${work_path}/N360_BRANCH/env.sh"
)

function check_and_mkdir()
{
    Debug "1 = $1 "
    if [ ! -d "$1" ];then
        mkdir -p $1
    Debug "1 = $1 "
        if [ ! -d "$1" ];then
    Debug "1 = $1 "
            return 1
        fi
    fi

    Debug "1 = $1 "
    return 0
}

TEMP=`getopt  -o "q" -l dst-path:,temp-sign,temp-sign-dir:,make-args: \
     -n "$0" -- "$@"`

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
                --dst-path)
                    if ! check_and_mkdir $2;then
                        Error "error dst_path[$2] $?."
                        exit 1
                    fi
                    dst_path=$2
                    C_Debug "\tdst-path: $2"
                    shift 2;;
                --temp-sign)
                    temp_sign=1
                    C_Debug "\ttemp-sign: $temp_sign"
                    shift 1;;
                --temp-sign-dir) 
                    if ! check_and_mkdir $2;then
                        Error "error temp-sign-dir[$2] $?."
                        exit 1
                    fi
                    temp_sign_dir=$2
                    C_Debug "\ttemp-sign-dir: $2"
                    shift 2;;
                --make-args)
                    make_args=$2
                    C_Debug "\tmake-args: $2"
                    shift 2;;
                --)
                    shift
                    break ;;
                *)
                    echo "Unknow option: $1 $2"
                    exit 1 ;;
        esac
done
C_Warn "================================================================\n"

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
