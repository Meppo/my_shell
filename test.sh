#!/bin/bash

my_shell_ipc_path=${my_shell_ipc_path:=/opt/work/shell/shell_ipc}
source $my_shell_ipc_path/log.sh

function test_usage()
{
    echo "Test usage:"
    echo " ./test.sh"
}

function test_func()
{
    echo "do test func..."
}

if [ "${FUNCNAME[0]}" = "main" ];then

test_func

fi #if [ "${FUNCNAME[0]}" = "main" ];then
