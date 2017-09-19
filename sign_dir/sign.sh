#!/bin/bash

root_dir=${root_dir:=$(cd `dirname $0`; pwd)}
build_sign_sciprt=$root_dir/sign_tool/build_sign_tool.sh

my_shell_ipc_path=${my_shell_ipc_path:=$root_dir/script}
logfile=${logfile:=/dev/stdout}
source $my_shell_ipc_path/log.sh

cmd=

# usage
function usage()
{
    echo "Usage: ./sign.sh [options] [other_args]"
    echo ""
    echo "Options:"
    echo "  -o, --make-tool: build official sign tool for app"
    echo "  e.g:" 
    echo "      ./sign.sh --make-tool <model> <app_sign> <app_center> <author> <sign_issur>"
    echo "      ./sign.sh --make-tool P1 airlink_app 360 YangWJ 1"
    echo "        <sign_issur>: "
    echo "              0-temp  1-ifenglian 3-netcore 4-100:reserve"
    echo "              101~1000 360's developer"
    echo "              1001~2000 ifenglian's developer"
    echo "              2001~3000 netcore's developer"
    echo "              3001~5000 reserve"
    echo ""
    echo "  -t, --make-tmp-tool: build temp sign tool with the expiration date"
    echo "  e.g:" 
    echo "      ./sign.sh --make-tmp-tool <model> <app_sign> <app_center> <expiration date>"
    echo "      ./sign.sh --make-tmp-tool P1 airlink_app 360 2017-11-31"
    echo ""
    echo "  -l, --list: list the all support <model|app_center> according to the keys have onwed"
    echo "  e.g:" 
    echo "      ./sign.sh --list"
    echo "      ./sign.sh -l"
    echo ""
    echo "  -a, --add-key: add/replace server key use to sign app"
    echo "  e.g:" 
    echo "      ./sign.sh --add-key <model> <app_center> key"
    echo "      ./sign.sh --add-key P1 360 /tmp/server_private.key"
    echo ""
    echo "  -d, --del-key: del server key"
    echo "  e.g:" 
    echo "      ./sign.sh --del-key <model> <app_center>"
    echo "      ./sign.sh --del-key P1 360   :  del the P1_360_server_private.key"
    echo "      ./sign.sh --del-key P1       :  del all keys for P1"
    echo "      ./sign.sh --del-key all      :  del all keys"
    echo ""
    echo "  -h, --help: show this usage text"
    echo ""
}

# support options
TEMP=`getopt  -o "haldot" -l help,make-tool,make-tmp-tool,add-key,del-key,list \
     -n "$0" -- "$@"`

if [ $? != 0 ] ; then echo "Try \"$0 -h\" for help text..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"
C_Warn "CMDLINE: $@"
C_Warn "ARGUS:"
while true ; do
        case "$1" in
                -h|--help) 
                    C_Debug "\thelp text\n"
                    cmd=print_usage
                    shift 1
                    ;;
                -l|--list) 
                    C_Debug "\tlist keys\n"
                    cmd=list_key
                    shift 1
                    ;;
                -a|--add-key)
                    C_Debug "\tadd key\n"
                    cmd=add_key
                    shift 1
                    ;;
                -d|--del-key)
                    C_Debug "\tdel key\n"
                    cmd=del_key
                    shift 1
                    ;;
                -o|--make-tool)
                    C_Debug "\tmake official sign tool\n"
                    cmd=make_tool
                    shift 1
                    ;;
                -t|--make-tmp-tool)
                    C_Debug "\tmake temp sign tool\n"
                    cmd=make_tmp_tool
                    shift 1
                    ;;
                --)
                    shift
                    break
                    ;;
                *)
                    echo "Unknow option: $1 $2\n"
                    exit 1
                    ;;
        esac
done
C_Warn "================================================================\n"

if [ -z "$cmd" ];then
    Error "few args..."
    usage
    exit 2
fi

function list_all_keys()
{
    C_Info "--------- support list ------------"
    local model=
    local key=
    local res=
    local author=

    C_Info "MODEL\tAPP_CENTER\n"
    for model in `ls $root_dir/KEY`
    do
        if [ ! -d "$root_dir/KEY/$model" ];then
            continue;
        fi
        for key in `ls $root_dir/KEY/$model/*_server_private.key`
        do
            res=$(echo $(basename $key) | grep -Eo '(netcore|360)')
            if [ -z "$res" ];then
                C_Info "$model\t360"
            else
                C_Info "$model\t$res"
            fi
        done
    done

    C_Info ""
}

#
# function: check whether support make sign tool 
#   for given model and app_center
# args:
#   $1: model
#   $2: app_center
# return:
#   0: support
#   >0: not support
#
function support_sign()
{
    local model=$1
    local app_center=$2
    local key_path=$root_dir/KEY/$model
    local res=

    if [ -z "$model" -o -z "$app_center" ];then
        Error "argus error: model:$model app_center:$app_center"
        return 1
    fi

    if [ ! -d "$key_path" ];then
        return 2
    fi

    for key in `ls $key_path/*_server_private.key`
    do
        res=$(echo $key | grep -o '$app_center')

        # consider app_center is 360 when key's name have no id
        # e.g: P1_server_private.key => model:P1  app_center:360
        if [ -z "$res" -a "$app_center" = "360" ];then
            return 0
        fi

        if [ -n "$res" ];then
            return 0
            break
        fi
    done

    return 3
}


# add/replace server keys
# args:
#   $1: model
#   $2: app_center: 360/netcore
#   $3: private key file path
# return:
#   0: success
#   >0: failed
#
function add_server_key()
{
    local model=$1
    local app_center=$2
    local private_key=$3
    local res=
    local last_key_dir=
    local last_key_name=
    local is_private_key=0

    if [ -z "$model" -o -z "$app_center" -o -z "$private_key" ];then
        Error "few argus: model:$model app_center:$app_center private_key:$private_key"
        usage
        return 1
    fi

    if [ ! -f "$private_key" ];then
        Error "error private key: $private_key not exist or is not file"
        return 2
    fi

    # check whether is rsa private key
    # file begin with "-----BEGIN RSA PRIVATE KEY-----"
    while read line
    do
        res=`echo $line | grep 'BEGIN RSA PRIVATE KEY'`
        if [ -n "$res" ];then
            is_private_key=1
            break;
        fi
    done < $private_key
    if [ $is_private_key -ne 1 ];then
        Error "error private key: $private_key is not a rsa private key"
        return 3
    fi

    #last private_key path format: [root_dir]/KEY/[model]/[model]_[app_center]_server_private.key
    last_key_dir=$root_dir/KEY/$model/
    last_key_name=${model}_${app_center}_server_private.key

    if [ ! -d "$last_key_dir" ];then
        C_Info "mkdir key dir[$last_key_dir] for $model ...\n"
        mkdir -p $last_key_dir
    fi

    cp $private_key $last_key_dir/$last_key_name
    if [ $? -ne 0 ];then
        Error "copy $private_key => $last_key_dir/$last_key_name failed."
    fi

    C_Info " server add private key for $model[$app_center] success.\n"

    return 0
}

# del server keys
# args:
#   $1: model
#   $2: app_center: 360/netcore
# return:
#   0: success
#   >0: failed
#
function del_server_key()
{
    local model=$1
    local app_center=$2
    local res=
    local last_key_path=

    if [ -z "$model" ];then
        Error "model is null"
        usage
        return 1
    fi

    if [ -z "$app_center" ];then
        if [ -d "$root_dir/KEY/$model" ];then
            Info "del dir[$root_dir/KEY/$model] for model[$model]..."
            rm -rf $root_dir/KEY/$model
        else
            Info "no dir[$root_dir/KEY/$model] to del for model[$model]..."
        fi
        return 0
    fi

    last_key_path=$root_dir/KEY/$model/${model}_${app_center}_server_private.key
    if [ -f "$last_key_path" ];then
        Info "del private_key[$last_key_path] for model[$model]..."
        rm -f $last_key_path
    else
        # P1_server_private.key = P1_360_server_private.key
        if [ "$app_center" = "360" ];then
            last_key_path=$root_dir/KEY/$model/${model}_server_private.key
            if [ -f "$last_key_path" ];then
                Info "del private_key[$last_key_path] for model[$model]..."
                rm -f $last_key_path
            fi
        fi
    fi

    res=`ls $root_dir/KEY/$model/`
    # empty dir, del this dir
    if [ -z "$res" ];then
        Info "del empty dir[$root_dir/KEY/$model] for model[$model]..."
        rm -rf $root_dir/KEY/$model
    fi

    C_Info " server del private key for $model[$app_center] success."
}

# build sign tool according to the model app_center ...
# args:
#   $1: model
#   $2: app_sign
#   $3: app_center: 360/netcore
#   $4: author
#   $5: sign_issur
#   $6: [optional] expiration time. e.g: 2017-09-31
# return:
#   0: success
#   >0: failed
#
function make_sign_tool()
{
    local model=$1
    local app_sign=$2
    local app_center=$3
    local author=$4
    local sign_issur=$5
    local expire_time=$6
    local server_private_key=

    if [ -z "$model" -o -z "$app_sign" \
         -o -z "$app_center" -o -z "$author" \
         -o -z "$sign_issur" \
        ];then
        Error "few arugs: model:$model app_sign:$app_sign app_center:$app_center author:$author sign_issur:$sign_issur"
        usage
        return 1
    fi

    if [ ! -f "$build_sign_sciprt" -o ! -x "$build_sign_sciprt" ];then
        Error "error sign script[$build_sign_sciprt] not exist or forbid execute."
        return 2
    fi

    support_sign $model $app_center
    if [ $? -ne 0 ];then
        Error "not support build sign tool for model[$model] app_center[$app_center]... "
        C_Warn "Try \"$0 --list \" to show all keys support now"
        C_Warn "Try \"$0 --add-key \" to add private key for new model/app_center"
        return 3
    fi
    server_private_key=$root_dir/KEY/$model/${model}_${app_center}_server_private.key
    if [ ! -f "$server_private_key" -a "$app_center" = "360" ];then
        server_private_key=$root_dir/KEY/$model/${model}_server_private.key
        if [ ! -f "$server_private_key" ];then
            Error "Can't find server_private_key[$server_private_key] for model[$model] app_center[$app_center]!"
            return 4
        fi
    fi

    # permanent author when sign_issur=1/2/3 (360/ifenglian/netcore)
    if [ "$sign_issur" == "1" ];then
        author=360
    elif [ "$sign_issur" == "2" ]; then
        author=ifenglian
    elif [ "$sign_issur" == "3" ]; then
        author=netcore
    fi

	echo "$build_sign_sciprt $server_private_key $model $app_sign $app_center $author $sign_issur $expire_time"
    $build_sign_sciprt $server_private_key $model $app_sign $app_center $author $sign_issur $expire_time

    return $?
}

#
# build temp sign tool according to the model app_center ...
# args:
#   $1: model
#   $2: app_sign
#   $3: app_center: 360/netcore
#   $4: expiration date , e.g: 2017-09-31
# return:
#   0: success
#   >0: failed
#
function make_tmp_sign_tool()
{
    local model=$1
    local app_sign=$2
    local app_center=$3
    local expire_time=$4
    local author=TempAuthor
    local sign_issur=0

    make_sign_tool $model $app_sign $app_center $author $sign_issur $expire_time
    if [ $? -ne 0 ];then
        return $?
    fi

    return 0
}

if [ "$cmd" = "make_tool" ];then
    make_sign_tool $@
elif [ "$cmd" = "make_tmp_tool" ];then
    make_tmp_sign_tool $@
elif [ "$cmd" = "add_key" ];then
    add_server_key $@
elif [ "$cmd" = "del_key" ];then
    del_server_key $@
elif [ "$cmd" = "list_key" ];then
    list_all_keys
elif [ "$cmd" = "print_usage" ];then
    usage
else
    C_Error "unknow cmd: $cmd"
    exit 3
fi

exit 0
