#!/bin/bash

# prevent include bar.sh multi times
inc_bar_flag=${inc_bar_flag:="first"}
if [ "$inc_bar_flag" != "first" ];then
    #echo "Have include $0, no need include again!"
    :
else
inc_bar_flag=included

processBar()
{
    now=$1
    all=$2
    percent=`awk BEGIN'{printf "%f", ('$now'/'$all')}'`
    len=`awk BEGIN'{printf "%d", (100*'$percent')}'`
    bar='>'
    for((i=0;i<len-1;i++))
    do
        bar="="$bar
    done
    printf "[%-100s][%03d/%03d]\r" $bar $len 100
}

# args:
#   arg1: cur pos
#   arg2: whole length
#   arg3: msg
function __moveBar()
{
    cur_pos=$1
    whole=$2
    msg=$3

    if [ $cur_pos -le 0 -o $whole -le 0 -o $cur_pos -gt $whole ];then
        return 1
    fi

    if [ $last_whole -ne $whole ] ; then
        last_pos=0
        last_whole=$whole
    fi

    if [ $last_pos -gt $whole ];then
        last_pos=$whole
    fi

    processBar $last_pos $whole
    while [ $last_pos -lt $cur_pos ]
    do
        let last_pos++
        processBar $last_pos $whole
        sleep 0.1
    done

    if [ -n "$msg" ];then
        printf "[%-100s]\n\r" "$msg"
    fi

#    if [ $last_pos -ge $whole ];then
#        printf "\n"
#    fi
}

# args:
#   arg1: cur pos
#   arg2: whole length
#   arg3: msg
last_pos=0
last_whole=0
function moveBar()
{
    __moveBar $@
}

fi #if [ "$inc_bar_flag" != "first" ];then
