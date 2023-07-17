#!/bin/sh

cnt=0
ipc_cnt=0
total_cnt=0
recover_mode=0

while [ true ]
do
    daemon_state=`ps |grep 'daemon' |grep -v grep`
    if [ x$daemon_state == x ];then
        cnt=`expr $cnt + 1`
        if [ "$cnt" -gt 3 ];then        
            echo "daemon is not work"
            recover_mode=1
        fi
    fi
    
    if [ ! -f "/mnt/mtd/aoni_ipc" ]; then
        ipc_cnt=`expr $ipc_cnt + 1`
        if [ "$ipc_cnt" -gt 3 ];then
            echo "aoni_ipc is not exist"
            recover_mode=1
        fi
    fi

    if [ $recover_mode == 1 ];then
        echo "start web recover mode !!"
        /mnt/mtd/web_recover &
        exit
    fi
    
    total_cnt=`expr $total_cnt + 1`
    if [ "$total_cnt" -gt 10 ];then
        exit
    fi

    sleep 1
done
