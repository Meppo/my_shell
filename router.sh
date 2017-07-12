#!/bin/sh

ip_cfg_file="/tmp/.__router_sh.ip"
app_cfg_file="/tmp/.__router_sh.app"
s=$1
ip=`[ -f $ip_cfg_file ] && cat $ip_cfg_file`
app=`[ -f $app_cfg_file ] && cat $app_cfg_file`

usage()
{
    echo ""
    echo "NAME:"
	echo "  $0 [flag] [sth.]"
    echo ""

    echo "DESCRIPTION:"
	echo "   this script use to do some repetition work with short cmd."
    echo ""

    echo "SPECIAL CMDS:"
    echo "  some cmd maybe need the param ip/app, so use this cmd to set default values."
    echo "      $0 ip <ip> : set the default param[ip] to cfg: /tmp/.__router_sh.ip"
    echo "      $0 app <app> : set the default param[app]to cfg: /tmp/.__router_sh.app"
    echo ""

	echo "FLAGS:"
	echo "   	0: copy /web /tmp/web , mount /web /tmp/web"
	echo "   	1: tftp 1.tar.gz , tar -zvxf, run /tmp/opk/bin/app"
	echo "   	2: tftp cgitest.cgi , cp cgitest.cgi to /tmp/web/cgi-bin/"
	echo "   	3: tftp busybox , link busybox to /tmp/some_bin"
	echo "   	4: tftp boa , then killall boa, run /tmp/boa"
	echo "   	5: tftp switch , then killall , run /tmp/switch"
	echo "   	6: tftp param_op, ./param_op save"
	echo "   	7: tftp special name and chmod +x "
	echo "   	  FORMAT:  ./router.sh 7 <file name> "
	echo "   	8: tftp igd_network "
	echo "   	9: killall switch and other process "
	echo "   	10: echo LD_LIBRARY_PATH "
	echo "   	11: killall opk"
    echo "   	12: re_tftp myself(route.sh)"
    echo "   	13: copy many switch lead to oom"
	echo "   	  FORMAT:  ./router.sh <copy count> "
    echo ""
}

if [ "$1" = "ip" -a -n "$2" ];then
    ip=$2
    echo $ip > $ip_cfg_file
    exit 0
fi
if [ -z "$ip" ];then
    echo "ERROR: no ip... use SPECIAL CMDS set default ip."
    usage
    exit 1
fi

if [ "$1" = "app" -a -n "$2" ];then
    app=$2
    echo $app > $app_cfg_file
    exit 0
fi
if [ -z "$app" ];then
    echo "ERROR: no app... use SPECIAL CMDS set default app."
    usage
    exit 1
fi

if [ $# -lt 1 ];then
	usage
	exit 0
fi

echo "================   CMD  ========================"
echo " OP=$s"
echo " IP=$ip"
echo " APP=$app"
echo "================================================"
echo ""

#app=arp_oversee
#app=devices_app
#app=anti_ddos
#app=multi_pppd
#app=airlink_app
#app=igd_safety_wireless_app
#app=igd_pptpc_app
#app=touch_link_app
#app=igd_l2tp_client_app
#app=universal_app
#app=orayapp
#app=igd_ap_app
#app=speed_host_app
#app=radio_power_app
#app=ap_timer_app
#app=qh_360
#app=fast_connect_app
#app=igd_wisp_app
#app=arp_oversee
#app=push_msg_app
#app=test_app
#app=hello
#app=device_manage_app

run_opk()
{
	cgi=app.cgi
	opk_dir=opk

	echo "----run ${opk_dir}/bin/${app}----"
	tftp -r 1.tar.gz -g $ip
	tar -zvxf 1.tar.gz
	chmod +x $opk_dir/bin/$app; killall $app; 
    sleep 1;
    export LD_LIBRARY_PATH=/tmp/$opk_dir/bin/ && /tmp/$opk_dir/bin/$app &
	mkdir -p /tmp/web/webnoauth
	chmod +x $opk_dir/webs/$cgi ; cp $opk_dir/webs/$cgi /tmp/web/webnoauth/na.cgi
}

killall_opk()
{
    killall $app && ps
}

run_cgitest()
{
	boa_cgi=cgitest.cgi
	echo "-----replace /tmp/web/cgi-bin/$boa_cgi----"

	tftp -r $boa_cgi -g $ip
	chmod +x $boa_cgi
	cp -f $boa_cgi /tmp/web/cgi-bin/
}

move_web()
{
    local web_path=/tmp/web
	echo "----mount /web to $web_path ----"

    if [ -d $web_path -a -n "`ls $web_path`" ];then
        echo "have mount."
        return 0
    fi

	mkdir -p /tmp/web
	cd /tmp/web; cp -af /web/* ./
	mount /tmp/web/ /web
}

run_busybox()
{
	bb=busybox
	if [ "x$1" = "x" ];then
		echo " give the bin_name let busybox link ,like ./$0 3 detect_wan "
		exit 0
	fi

	echo "----link busybox /web to /tmp/$1 ----"
	tftp -r $bb -g $ip
	chmod +x $bb
	ln -sf $bb $1
}

run_boa()
{
	echo "----tftp boa then run "
	killall boa
	tftp -r boa -g $ip
	chmod +x boa
	./boa -p /web -f /var/boa.conf &
}

run_switch()
{
    kill -SIGTERM -1
	tftp -r switch -g $ip
	chmod +x switch 
	./switch &
}

run_param_op()
{
    tftp -r param_op -g $ip
    chmod +x param_op
    ./param_op save
}

tftp_file()
{
    shift
    while [ $# -gt 0 ]; do
        echo "----tftp $1 and chmod +x ------"
        tftp -r "$1" -g "$ip"
        chmod +x "$1"
        shift 
    done
}

tftp_network()
{
    echo "----tftp network and chmod +x ------"
    tftp -g "$ip" -r igd_network_server
    tftp -g "$ip" -r srv_test
    tftp -g "$ip" -r libnetwork_ipc.so
    chmod +x igd_network_server srv_test libnetwork_ipc.so
    echo "export LD_LIBRARY_PATH=/tmp;./igd_network_server"
}

run_killall()
{
    echo "----killall switch and other process----"
    kill -SIGTERM -1
}

run_echo_help()
{
    echo "export LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:"
}

re_tftp_route_sh()
{
    tftp -r router.sh -g $ip; chmod +x router.sh
}

copy_to_oom()
{
    local count=10
	if [ "x$1" != "x" ];then
        count=$1
	fi
    echo "begin copy switch $count times..."

    local i=0
    while true
    do
        if [ $i -lt $count ];then
            echo "copy switch to /tmp/switch_$$_$i"
            cp -f /bin/switch /tmp/switch_$$_$i
        else
            break
        fi
        i=$(($i+1))
    done
}

case $s in
    0)
	    move_web
        break
        ;;
    1)
	    run_opk 
        break
        ;;
    2)
	    run_cgitest
        break
        ;;
    3)
	    run_busybox $2
        break
        ;;
    4)
	    run_boa
        break
        ;;
    5)
	    run_switch
        break
        ;;
    6)
	    run_param_op
        break
        ;;
    7)
    	tftp_file $@
        break
        ;;
    8)
	    tftp_network
        break
        ;;
    9)
	    run_killall
        break
        ;;
    10)
	    run_echo_help
        break
        ;;
    11)
	    killall_opk
        break
        ;;
    12)
	    re_tftp_route_sh
        break
        ;;
    13)
	    copy_to_oom $2
        break
        ;;
    *)
        echo "unknow op: $s"
        break
        ;;
esac
