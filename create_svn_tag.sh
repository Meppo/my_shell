#!/bin/sh

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
logfile=${logfile:=/dev/stdout}
source $my_shell_ipc_path/log.sh
source $my_shell_ipc_path/add_prop.sh

src_svn_path="svn://192.168.30.163/igd/29XXNR/MTK/branches"
dst_tag_svn_path="svn://192.168.30.163/igd/29XXNR/MTK/branches/P1_tags"


add_prop_for_multi_dir()
{
    local file=$1
    local sub_dir=
    local prop_name=
    local prop_value=

    local i=
    local _model=
    local _ver=
    local _cat=
    local _time=
    local _svn_num=
    local _src_pathname=
    local _log_file=

    while read line
    do
        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        echo "deal $line ..."

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: P1|2.0.50.47726|development|2016-12-30 18:19|47726|RTL-360|47726.txt
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _model=$split
                    if [ -z "split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                "2")
                    _ver=$split
                    if [ -z "split" ];then
                        Error "Null Version."
                        exit 1
                    fi
                ;;
                "3")
                    _cat=$split
                    if [ -z "split" ];then
                        Error "Null Category."
                        exit 1
                    fi
                ;;
                "4")
                    _time=$split
                ;;
                "5")
                    _svn_num=$split
                    if [ -z "split" ];then
                        Error "Null svn_num."
                        exit 1
                    fi
                ;;
                "6")
                    _src_pathname=$split
                    if [ -z "split" ];then
                        Error "Null src_pathname."
                        exit 1
                    fi
                ;;
                "7")
                    _log_file=$split
                    if [ ! -s "$split" ];then
                        Error "Error log file $split."
                        exit 1
                    fi
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 7 ];then
                break
            fi
        done

        if [ "$_model" = "P1" ];then
            sub_dir=${_ver}_${_cat}
        else
            sub_dir=${_model}_${_ver}_${_cat}
        fi
        Info "sub_dir=$sub_dir"

        # have exist?
        svn info $dst_tag_svn_path/$sub_dir
        if [ $? -ne 0 ];then
            #svn cp
            if [ -n "$_log_file" ];then
                Debug "svn cp $src_svn_path/$_src_pathname@$_svn_num $dst_tag_svn_path/$sub_dir -F $_log_file"
                svn cp $src_svn_path/$_src_pathname@$_svn_num $dst_tag_svn_path/$sub_dir -F $_log_file
            else
                Debug "svn cp $src_svn_path/$_src_pathname@$_svn_num $dst_tag_svn_path/$sub_dir -m \"create tag $sub_dir\""
                svn cp $src_svn_path/$_src_pathname@$_svn_num $dst_tag_svn_path/$sub_dir -m "create tag $sub_dir"
            fi
        else
            Debug "have create tag: $dst_tag_svn_path/$sub_dir, no need create again!"
        fi

        #svn co
        if [ ! -d "$sub_dir" ];then
            Debug "rm -rf $sub_dir"
            rm -rf $sub_dir
            Debug "svn co $dst_tag_svn_path/$sub_dir --depth immediates"
            svn co $dst_tag_svn_path/$sub_dir --depth immediates
        fi

        #svn propset
        add_prop $sub_dir "Category" "$_cat"
        if [ -n "$_time" ];then
            add_prop $sub_dir "Release_time" "$_time"
        fi
        add_prop $sub_dir "Revision_num" "$_svn_num"
        add_prop $sub_dir "Svn_path" "$_src_pathname"

    done < $file
}

del_prop_for_multi_dir()
{
    local file=$1
    local sub_dir=
    local prop_name=
    local prop_value=

    local i=
    local _model=
    local _ver=
    local _cat=
    local _time=
    local _svn_num=
    local _src_pathname=
    local _log_file=

    while read line
    do
        if [ -z "$line" ];then
            continue;
        fi

        # comment begin with "#"
        if [ "${line:0:1}" = "#" ];then
            continue;
        fi

        echo "deal $line ..."

        # illegal item
        local have_se=`echo $line | grep '|'`
        if [ -z "$have_se" ];then
            continue;
        fi

        # parse item:
        #  e.g: P1|2.0.50.47726|development|2016-12-30 18:19|47726|RTL-360|47726.txt
        i=1
        while true
        do
            local split=`echo $line | cut -d '|' -f$i`

            case "$i" in
                "1") 
                    _model=$split
                    if [ -z "split" ];then
                        Error "Null Model."
                        exit 1
                    fi
                ;;
                "2")
                    _ver=$split
                    if [ -z "split" ];then
                        Error "Null Version."
                        exit 1
                    fi
                ;;
                "3")
                    _cat=$split
                    if [ -z "split" ];then
                        Error "Null Category."
                        exit 1
                    fi
                ;;
                "4")
                    _time=$split
                ;;
                "5")
                    _svn_num=$split
                ;;
                "6")
                    _src_pathname=$split
                ;;
                "7")
                    _log_file=$split
                ;;
                *)
                    break
                ;;
            esac

            let i++

            if [ $i -gt 7 ];then
                break
            fi
        done

        if [ "$_model" = "P1" ];then
            sub_dir=${_ver}_${_cat}
        else
            sub_dir=${_model}_${_ver}_${_cat}
        fi
        Info "sub_dir=$sub_dir"

        if [ -d "$sub_dir" ];then
            Info "rm -rf $sub_dir"
            rm -rf $sub_dir
        fi

    done < $file
}

# do things we need to do when excute this script directly,not source this script.
#   if source this script by other scripts, FUNCNAME[]: source main
if [ "${FUNCNAME[0]}" = "main" ];then

usage()
{
    echo "Usage:"
    echo "  $0 [options] filename "
    echo ""
    echo " Options:"
    echo "   -q: quiet mode"
    echo "   -d: del local dir in filename"
    echo ""
    echo "  [file] format: "
    echo "   item format:"
    echo "      M|VER|Cat|Time|SVN_Ver|Src_path|Log_file"
    echo "   item example:"
    echo "      P1|2.0.50.47726|development|2016-12-30 18:19|47726|RTL-360|47726.txt"
    echo "   we will do this:"
    echo "     svn cp $src_svn_path/[Src_path]@[SVN_Ver] $dst_tag_svn_path/[M]_[VER]_[Cat]/ -F [Log_file]"
    echo "     svn co $dst_tag_svn_path/[M]_[VER]_[Cat]/ --depth immediates"
    echo "     #local dir name:[M]_[VER]_[Cat]"
    echo "     cd [M]_[VER]_[Cat]"
    echo "     svn propset Category [Cat]"
    echo "     svn ci . -m \"add prop Category = [Cat]\""
    echo "     svn propset Release_time [Time]"
    echo "     svn ci . -m \"add prop Release_time = [Time]\""
    echo "     svn propset Revision_num [SVN_Ver]"
    echo "     svn ci . -m \"add prop Revision_num = [SVN_Ver]\""
    echo "     svn propset Svn_path [Src_path]"
    echo "     svn ci . -m \"add prop Svn_path = [Src_path]\""
    echo "   the result:"
    echo "     svn log -v --stop-on-copy $dst_tag_svn_path/[M]_[VER]_[Cat]/"
    echo "     svn proplist -v $dst_tag_svn_path/[M]_[VER]_[Cat]/"
    echo ""
}

del_dir_flag=0

TEMP=`getopt  -o "dq" -n "$0" -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"
C_Warn "CMDLINE: $@"
C_Warn "ARGUS:"
while true ; do
        case "$1" in
                -d) 
                    del_dir_flag=1
                    C_Debug "\tdel_mode: del_dir_flag=$del_dir_flag"
                    shift 1;;
                -q) 
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

if [ $# -lt 1 ];then
    Error "too few argus."
    usage
    exit 0
fi

if [ ! -f "$1" ];then
    Error "$1 is not a file!"
    exit 1
fi

if [ $del_dir_flag -ne 0 ];then
    Debug "del dir according to the file[$1]"
    del_prop_for_multi_dir $1
    exit $?
fi

echo "Deal multi_dir in file[$1]!"
add_prop_for_multi_dir $1 

fi #if [ "${FUNCNAME[0]}" = "main" ];then
