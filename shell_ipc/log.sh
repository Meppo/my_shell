#!/bin/bash

# prevent include log.sh multi times
inc_log_flag=${inc_log_flag:="first"}
if [ "$inc_log_flag" != "first" ];then
    #echo "Have include $0, no need include again!"
    :
else
inc_log_flag=included


#可将log函数单独放一个文件，通过.命令引入，这样就可以共用了
#. log.sh 
#设置日志级别
loglevel=0 #debug:0; info:1; warn:2; error:3
logfile=${logfile:="$0.log.$$"}
function log {
        local msg
        local funcs
        local line
        local logtype
        logtype=$1
        c=$2
        line=$3
        funcs=${FUNCNAME[@]:2:${#FUNCNAME[@]}}
        shift 3
        msg=$*
        datetime=`date '+%F %H:%M:%S'`
        #使用内置变量$LINENO不行，不能显示调用那一行行号
        #logformat="[${logtype}]\t${datetime}\tfuncname:${FUNCNAME[@]} [line:$LINENO]\t${msg}"
        #logformat="[${logtype}][${datetime}][${FUNCNAME[@]/log/}][`caller 0 | awk '{print$1}'`]: ${msg}"
        if [ $c -eq 1 ];then
            logformat="${msg}"
        else
            logformat="[${logtype}][${datetime}][${funcs}][${line}]: ${msg}\n"
        fi

        #funname格式为log error main,如何取中间的error字段，去掉log好办，再去掉main,用echo awk? ${FUNCNAME[0]}不能满足多层函数嵌套
        {
        case $logtype in  
                debug)
                        [[ $loglevel -le 0 ]] && echo -e "\033[37m${logformat}\033[0m" ;;
                info)
                        [[ $loglevel -le 1 ]] && echo -e "\033[32m${logformat}\033[0m" ;;
                warn)
                        [[ $loglevel -le 2 ]] && echo -e "\033[33m${logformat}\033[0m" ;;
                error)
                        [[ $loglevel -le 3 ]] && echo -e "\033[31m${logformat}\033[0m" ;;
        esac
        #} > /dev/stdout
        #} | tee -a $logfile
        } >> $logfile
}

# no prefix
function C_Error()
{
    log error 1 `caller 0 | awk '{print$1}' ` $*
}

function C_Info()
{
    log info 1 `caller 0 | awk '{print$1}' ` $*
}

function C_Warn()
{
    log warn 1 `caller 0 | awk '{print$1}' ` $*
}

function C_Debug()
{
    log debug 1 `caller 0 | awk '{print$1}' ` $*
}

function Error()
{
    log error 0 `caller 0 | awk '{print$1}' ` $*
}

function Info()
{
    log info 0 `caller 0 | awk '{print$1}' ` $*
}

function Warn()
{
    log warn 0 `caller 0 | awk '{print$1}' ` $*
}

function Debug()
{
    log debug 0 `caller 0 | awk '{print$1}' ` $*
}

fi #if [ "$inc_log_flag" != "first" ];then
