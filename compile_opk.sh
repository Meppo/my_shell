#!/bin/bash
# This script use to compile opk => *.opk

root_dir=$(cd `dirname $0`; pwd)
support_opk_list_file=.compile_opk_support.list

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
export my_shell_ipc_path=$my_shell_ipc_path

logfile=${logfile:=/dev/stdout}
export logfile=$logfile

source $my_shell_ipc_path/log.sh

function usage()
{
    echo "Usage:"
    echo "  $0 [options] [opk_name] [project_list...]"
    echo ""
    echo "Options:"
    echo "  -q                           quiet mode"
    echo "  -t, --dest <dst path>        the path restore the opk after compiled"
    echo "  -m, --make-args <make args>  compile extra arguments "
    echo ""
    echo "  -a, --add <app_sign> <model> <app path> <env path> <opk name>"
    echo "                              add new opk compile info about how to compile opk, where to compile it."
    echo "   e.g: "
    echo "      $0 --add airlink_app P1 /opt/N360_P1/user/app/airlink_app /opt/N360_P1/env.sh airlink_app.opk"
    echo ""
    echo "  -d, --del <app_sign> <model> del opk compile info"
    echo "   e.g: "
    echo "      $0 --del airlink_app P1 "
    echo ""
    echo "  -l, --list                  list all opk compile info support now"
    echo ""
    echo "e.g:"
    echo "  ./opk_sign --make-args 'CC=mips-linux-gcc install' airlink_app P0 P1 -t /tmp/opk_dir"
    echo "      compile airlink_app for P0, P1, then copy the airlink_app.opk => /tmp/opk_dir/"
    echo ""
}

#
# args:
#  $1: dir need to check/mkdir
# return:
#  0: suucess
#  1 : failed
#
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

TEMP=`getopt  -o "qt:m:adl" -l dest:,make-args:,add,del,list \
     -n "$0" -- "$@"`

quiet_mode=0
output=/dev/stdout

dst_path=${dst_path:=$root_dir}
dst_prefix=`date "+%Y%m%d_%H%M"`
make_args=
cmd=make #default action

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
                    shift 1
                    ;;
                -t|--dest)
                    if ! check_and_mkdir $2;then
                        Error "error dst_path[$2] $?."
                        exit 1
                    fi
                    # del last char '/'
                    dst_path=`cd $2; pwd`
                    C_Debug "\tdest: $2"
                    shift 2
                    ;;
                -m|--make-args)
                    make_args=$2
                    C_Debug "\tmake-args: $2"
                    shift 2
                    ;;
                -a|--add)
                    cmd=add
                    C_Debug "\tadd"
                    shift 1
                    ;;
                -d|--del)
                    cmd=del
                    C_Debug "\tdel"
                    shift 1
                    ;;
                -l|--list)
                    cmd=list
                    C_Debug "\tlist"
                    shift 1
                    ;;
                --)
                    shift
                    break 
                    ;;
                *)
                    echo "Unknow option: $1 $2"
                    exit 1 
                    ;;
        esac
done
C_Warn "================================================================\n"

list_support_opk()
{
    local i=
    local _app_sign=
    local _model=
    local _opk_path=
    local _env_path=
    local _opk_name=

    C_Info "====================== support opk list ==========================="
    C_Info "OPK_SIGN\tMODEL\tOPK_PATH\t\t\t\tENV_PATH\t\tOPK_NAME"
    while read line
    do
        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: airlink_app|P1|/opt/N360_P1/user/app/airlink_app|/opt/N360_P1/env.sh|airlink_app.opk
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _app_sign=$split
                    if [ -z "$split" ];then
                        Error "Null appsign."
                        exit 1
                    fi
                ;;
                "2")
                    _model=$split
                    if [ -z "$split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                "3")
                    _opk_path=$split
                    if [ -z "$split" ];then
                        Error "Null opk path."
                        exit 1
                    fi
                ;;
                "4")
                    _env_path=$split
                    if [ -z "$split" ];then
                        Error "Null env path."
                        exit 1
                    fi
                ;;
                "5")
                    _opk_name=$split
                    if [ -z "$split" ];then
                        Error "Null opk name."
                        exit 1
                    fi
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 5 ];then
                break
            fi
        done

        C_Info "$_app_sign\t$_model\t$_opk_path\t$_env_path\t$_opk_name"
    done < $support_opk_list_file
}

function add_support_opk()
{
    local app_sign=$1
    local model=$2
    local opk_path=$3
    local env_path=$4
    local opk_name=$5
    local same_opk_line=

    local _line_no=0
    local i=
    local _app_sign=
    local _model=

    if [ ! -d "$opk_path" ];then
        Error "opk_path[$opk_path] error, not exist or is no dir."
        return 1
    fi

    if [ ! -f "$env_path" -o ! -x "$env_path" ];then
        Error "env_path[$opk_path] error, not exist or forbid execute ."
        return 1
    fi

    # have exist this item?
    while read line
    do
        let _line_no++

        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: airlink_app|P1|/opt/N360_P1/user/app/airlink_app|/opt/N360_P1/env.sh|airlink_app.opk
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _app_sign=$split
                    if [ -z "$split" ];then
                        Error "Null appsign."
                        exit 1
                    fi
                ;;
                "2")
                    _model=$split
                    if [ -z "$split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 2 ];then
                break
            fi
        done

        if [ "$_app_sign" = "$app_sign" ];then
            same_opk_line=$_line_no
        fi

        if [ "$_app_sign" = "$app_sign" -a "$model" = "$_model" ];then
            C_Info "have exist the item app_sign[$_app_sign] model[$_model], no need add again."
            return 0
        fi
    done < $support_opk_list_file

    if [ -z "$same_opk_line" ];then
        same_opk_line='$'
    fi

    #add item to file with sed
    sed -i "$same_opk_line a$app_sign|$model|$opk_path|$env_path|$opk_name" $support_opk_list_file
    C_Info "add item app_sign[$app_sign] model[$model] to $support_opk_list_file SUCCESS."

    return 0
}

function del_support_opk()
{
    local app_sign=$1
    local model=$2
    local same_item_line=

    local _line_no=0
    local i=
    local _app_sign=
    local _model=

    # have exist this item?
    while read line
    do
        let _line_no++

        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: airlink_app|P1|/opt/N360_P1/user/app/airlink_app|/opt/N360_P1/env.sh|airlink_app.opk
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _app_sign=$split
                    if [ -z "$split" ];then
                        Error "Null appsign."
                        exit 1
                    fi
                ;;
                "2")
                    _model=$split
                    if [ -z "$split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 2 ];then
                break
            fi
        done

        if [ "$_app_sign" = "$app_sign" -a "$model" = "$_model" ];then
            same_item_line=$_line_no
            break
        fi
    done < $support_opk_list_file

    if [ -z "$same_item_line" ];then
        C_Info "Not exist the item app_sign[$app_sign] model[$model] to del."
        return 0
    fi

    #del item from file with sed
    sed -i "$same_item_line d" $support_opk_list_file
    C_Info "del item app_sign[$app_sign] model[$model] from $support_opk_list_file SUCCESS."

    return 0
}

#
#  return value with args:
#    $1: opk_path
#    $2: env_path
#    $3: opk_name after compiled
#
function get_compile_info()
{
    local __opk_path_var=$3
    local __env_path_var=$4
    local __opk_name_var=$5

    local _app_sign=
    local _model=
    local _opk_path=
    local _env_path=
    local _opk_name=
    local i=0

    while read line
    do
        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: airlink_app|P1|/opt/N360_P1/user/app/airlink_app|/opt/N360_P1/env.sh|airlink_app.opk
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _app_sign=$split
                    if [ -z "$split" ];then
                        Error "Null appsign."
                        exit 1
                    fi
                ;;
                "2")
                    _model=$split
                    if [ -z "$split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                "3")
                    _opk_path=$split
                    if [ -z "$split" ];then
                        Error "Null opk path."
                        exit 1
                    fi
                ;;
                "4")
                    _env_path=$split
                    if [ -z "$split" ];then
                        Error "Null env path."
                        exit 1
                    fi
                ;;
                "5")
                    _opk_name=$split
                    if [ -z "$split" ];then
                        Error "Null opk name."
                        exit 1
                    fi
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 5 ];then
                break
            fi
        done

        if [ "$_app_sign" != "$1" -o "$_model" != "$2" ];then
            continue
        fi

        eval $__opk_path_var="'$_opk_path'"
        eval $__env_path_var="'$_env_path'"
        eval $__opk_name_var="'$_opk_name'"
        return 0
    done < $support_opk_list_file

    return 1
}

function compile_opk()
{
    local app_sign=$1
    local model=
    local opk_path=
    local env_path=
    local opk_name=
    local dst_opk_name=
    local dst_json_name=

    shift 1

    for model in $@
    do
        opk_path=
        env_path=
        opk_name=

        get_compile_info $app_sign $model opk_path env_path opk_name
        if [ $? -ne 0 ];then
            Error "not support make the opk app_sign[$app_sign] model[$model]... "
            C_Warn "Try \"$0 -l \" to show all opk support now"
            C_Warn "Try \"$0 -a \" to add new opk compile info"
            return 1
        fi

        dst_opk_name=${dst_path}/${app_sign}_${model}_${dst_prefix}.opk
        dst_json_name=${dst_path}/${app_sign}_${model}_${dst_prefix}.json

        #Debug "${app_sign} ${model} => $opk_path $env_path $opk_name dst_opk_name=${dst_opk_name} dj=${dst_json_name}"

        # compile opk
        {
            cd `dirname ${env_path}` \
                && source ${env_path} `dirname ${env_path}` \
                && echo "userdir=$USERDIR"\
                && cd ${opk_path}\
                && make clean && make $make_args \
                && if test -f $opk_name; then cp $opk_name ${dst_opk_name} ;\
                    cp app.json ${dst_json_name}; fi & 
        }  > $output 2>&1
        wait $!
        st=$?

        if [ $st -ne 0 ];then
            Error "Compile $app_sign for $model failed, exit st=$st."
            return $st
        fi

        Info "Compile $app_sign for $model SUCCESS, dst_opk_name=${dst_opk_name}"
    done

    return 0
}

Debug " args: $@ root_dir=$root_dir cmd=$cmd"

if [ "$cmd" = "list" ];then
    list_support_opk $@
elif [ "$cmd" = "add" ];then
    if [ $# -lt 5 ];then
        Error "few argus"
        usage
        exit 2
    fi
    add_support_opk $@
elif [ "$cmd" = "del" ];then
    if [ $# -lt 2 ];then
        Error "few argus"
        usage
        exit 2
    fi
    del_support_opk $@
elif [ "$cmd" = "make" ];then
    if [ $# -lt 2 ];then
        Error "few argus"
        usage
        exit 2
    fi
    compile_opk $@
fi

exit $?
