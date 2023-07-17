#!/bin/sh

UNIT_CHECK_T=5
MYDLINK_BASE="/mydlink"
PID_BASE="/tmp/run"
restart_cnt=0
WATCHDOG_PID="$PID_BASE/mydlink-watch-dog.pid"
TMP_MYDLINK="/tmp/mydlink"

# CA_CHECK_INTERVAL = 1209600 which means 86400 * 14 = 2weeks 
# 1209600/5 = 241920
CA_CHECK_INTERVAL=241920
CA_RETRY_INTERVAL=720
ca_check_counter=0
CA_CHECK_URL="http://ca-mgr.auto.mydlink.com/default/ca-bundle.crt"
CA_CHECK_FLAG="/tmp/.ca.check.flag"
CA_CRT_FILE="/mydlink/config/ca-bundle.crt"
CA_SIG_FILE="/mydlink/config/ca-bundle.sig"
SYNC_OOB_FILE="/mydlink/config/sync_oob"
ca_next_check_time=0
MDB_PATH="/mydlink/mdb"
MDB_COMMAND_PATH="LD_LIBRARY_PATH=/mydlink/lib $MDB_PATH"
SMART_ROUTER_PORT="wss://0.0.0.0:8082/SwitchCamera"
FW_PAGE_SIZE=$(grep ^KernelPageSize /proc/self/smaps | awk 'NR==1 {print $2}')
INTERFACE_FILE="$MYDLINK_BASE/interface"

mkdir -p $TMP_MYDLINK
mkdir -p $PID_BASE

# read mydlink control service ip from 'interface'
if [ -f ${MDB_PATH} ]; then
  if [ -f $INTERFACE_FILE ] ; then
    INTERFACE=`cat $INTERFACE_FILE`
    LANIP=`ifconfig $INTERFACE | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
  fi
  if [ -n "$LANIP" ] ; then
    SMART_ROUTER_PORT="wss://$LANIP:53674/SwitchCamera"
  fi
fi

#
log() {
  #echo "[`date +"%Y-%m-%d %H:%M:%S"`] $1" >> $LOG_FILE
  echo "[`date +"%Y-%m-%d %H:%M:%S"`] $1" > /dev/null 2>&1
}

# replace mdb path
if [ -f ${MDB_PATH} ]; then
    mdb_path="$MDB_PATH"
    mdb_cmd_path="$MDB_COMMAND_PATH"
    smart_router_port=$SMART_ROUTER_PORT
else
    mdb_path="mdb"
    mdb_cmd_path="mdb"
fi

# Manage the watchdog PID
wd_pid="-1"
if [ -f ${WATCHDOG_PID} ]; then
    wd_pid=`cat ${WATCHDOG_PID}`
fi
if [ -d "/proc/$wd_pid" ] && [ "0$wd_pid" -ne "0$$" ]; then
  log "Watchdog is running, exit."
  exit 255
else
  echo "$$" > "${WATCHDOG_PID}"
fi


if [ ! -s /mydlink/config/device.cfg ]; then
  if [ -s /mydlink/config/device.mmt ]; then
    `cp /mydlink/config/device.mmt /mydlink/config/device.cfg`
  else
    `cp /mydlink/device.cfg /mydlink/config/device.cfg`
  fi
fi

# modify the cache of kernel by checking the the dev_list
# the model which support SDcard = return 32(0x20) in ctrl value should be modified
mdb_dev_list=`LD_LIBRARY_PATH="/mydlink/lib" $mdb_path get dev_list`
DEV_LIST_DECODED=$(echo -e "$mdb_dev_list" | sed 's/+/ /g;s/%/\\\\x/g;' | sed 's/+/ /g;s/&/\n/g' |awk -F'=' '{if($1=="C") print $2}' | grep 32 -c)

mdb_dev_model=`LD_LIBRARY_PATH="/mydlink/lib" $mdb_path get dev_model`

if [ "DCS-H100" = "$mdb_dev_model" ] || [ "DCS-8330LH" = "$mdb_dev_model" ] || [ -f ${MDB_PATH} ]; then
  mem_max_da_adaptor=100000
  mem_max_sa=100000
  mem_max_rec=200000
else
  mem_max_da_adaptor=30000
  mem_max_sa=10000
  mem_max_rec=40000
fi

if [ "DIR-X3260" = "$mdb_dev_model" ] || [ "M32" = "$mdb_dev_model" ]; then
  mem_max_da_adaptor=500000
fi

clear_pid() {
 rm $PID_BASE/da_adaptor.pid
 rm $PID_BASE/sa.pid
 rm $PID_BASE/rec.pid
 restart_cnt=0
}

check_memory() {

  if [ -z $1 ];then
  # Don't modify the line, because of it will be replaced by watchdog.
  # If need, please modify env variable (MEM_THRESHOLD).
  Memory_Threshold=5000

  Free_Memory=`cat /proc/meminfo | grep 'MemFree:' | sed 's/^.*MemFree://g' | sed 's/kB*$//g'`

  if [ $Free_Memory -le $Memory_Threshold ]; then
     sync; echo 3 > /proc/sys/vm/drop_caches
     echo "!!! Notice! Clear memory cache !!!"
  fi
  	return
  fi

  # check if the program exists or not
  if [ ! -f "$MYDLINK_BASE/$1" ] && [ ! -z $1  ]; then
	return
  else
  # check if process exists by pid
  pid="-1"
  if [ -f "${PID_BASE}/${1}.pid" ]; then
    pid=`cat ${PID_BASE}/${1}.pid`
  fi
  if [ -f "/proc/${pid}/statm" ] && [ -n "$FW_PAGE_SIZE" ]; then
	MEM_PAGES=`cat /proc/${pid}/statm | awk '{print $1}'`
	allocated_memory=`expr $MEM_PAGES \* $FW_PAGE_SIZE`
	if [ $allocated_memory -gt $2 ]; then
		killall -9 $1
    fi
  fi
  fi
}

check_alive() {
  # check if the program exists or not
  if [ ! -f "$MYDLINK_BASE/$1" ]; then
    return
  fi

  # check if process exists by pid
  pid="-1"
  state=""
  if [ -f "${PID_BASE}/${1}.pid" ]; then
    pid=`cat ${PID_BASE}/${1}.pid`
  fi
  if [ -d "/proc/${pid}" ]; then
    state=`cat /proc/${pid}/stat | awk '{print $3}'`
    if [ "${state}" != "Z" ]; then
      restart_cnt=0
      return
    fi
  fi

  restart_cnt=`expr $restart_cnt + 1`
  if [ "$restart_cnt" -gt 6 ]; then
    log "reboot cause device agent can't startup"
    reboot
  fi

  log "$1 is not running! ($pid)"
  # kill all remaining processes and wait a moment
  killall -9 $1 2>/dev/null
  sleep 1

  # launch the process
  # $MYDLINK_BASE/$1 $2 >> "${LOG_BASE}/${1}.log" 2>&1 &
  
  if [ -f ${MDB_PATH} ]; then
  LD_LIBRARY_PATH="/mydlink/lib" /mydlink/$1 "$2" "$3" > /dev/null 2>&1 &
  else
  LD_LIBRARY_PATH="/mydlink/lib" /mydlink/$1 "$2" > /dev/null 2>&1 & 
  fi
  
  pid="$!"
  res="$?"
  # keep the pid
  echo $pid > "${PID_BASE}/${1}.pid"

  log " - launch $1 ($pid, $res)"
}

check_cert() {

  ca_check_counter=`expr $ca_check_counter + 1`

  if [ -f $CA_CHECK_FLAG ]; then
    ca_next_check_time=`cat $CA_CHECK_FLAG`
  else
    ca_next_check_time=0
  fi

  if [ $ca_check_counter -lt $ca_next_check_time ]; then
    return 0
  fi

  eval $MYDLINK_BASE/ca-refresh $CA_CHECK_URL /mydlink/config /tmp > /dev/null 2>&1
  res=$?
  if [ $res -eq 0 ];then
    mv /tmp/ca-bundle.crt $CA_CRT_FILE
    mv /tmp/ca-bundle.sig $CA_SIG_FILE
    clear_pid
    ca_next_check_time=$CA_CHECK_INTERVAL
  elif [ $res -eq 1 ];then
    ca_next_check_time=$CA_CHECK_INTERVAL
  else
    ca_next_check_time=$CA_RETRY_INTERVAL
  fi
  echo -n $ca_next_check_time > $CA_CHECK_FLAG
  #echo "next check time:$ca_next_check_time, now:$now, diff:$(($ca_next_check_time - $now))"
  ca_check_counter=0
}

dump_while_loop() {
  (
  while [ 1 ]
  do
    echo "mydlink watchdog is running in dummy loop."
    sleep $UNIT_CHECK_T
  done
  ) &
}

stop_agent() {
  # check if the program exists or not
  if [ ! -f "$MYDLINK_BASE/$1" ]; then
    return
  fi

  # check if process exists by pid
  pid="-1"
  if [ -f "${PID_BASE}/${1}.pid" ]; then
    pid=`cat ${PID_BASE}/${1}.pid`
    rm $PID_BASE/${1}.pid
  fi

  if [ -d "/proc/${pid}" ]; then
    killall -9 $1 2>/dev/null
    sleep 1
  fi

  # double check the program exists or not
  pid=`pidof $1`
  if [ -n "$pid" ]; then
    killall -9 $1 2>/dev/null
    sleep 1
  fi
}

if [ "$1" == "restart" ]; then
  stop_agent da_adaptor
  stop_agent sa
  stop_agent rec
fi

mdb_oob_st=`LD_LIBRARY_PATH="/mydlink/lib" $mdb_path get oob_changed`
if [ "$mdb_oob_st" == "1" ] && [ -f $SYNC_OOB_FILE ]; then
  dump_while_loop
  exit 0
fi

(
while [ 1 ]
do
  curpid=`cat ${WATCHDOG_PID}`
  if [ "0$$" -ne "0$curpid" ]; then
    log "Unexpected pid (self: $$ cur: $curpid), exit!"
    exit 255
  fi

  check_cert

  if [ ! -f $SYNC_OOB_FILE ]; then
    if [ -f ${MDB_PATH} ]; then
    check_alive da_adaptor "-s $mdb_cmd_path" "-p$smart_router_port"
    else
    check_alive da_adaptor "-s $mdb_cmd_path"
    fi
  fi

  mdb_reg_st=`LD_LIBRARY_PATH="/mydlink/lib" $mdb_path get register_st`
  if [ "$mdb_reg_st" == "1" ] && [ "$mdb_oob_st" != "1" ]; then
  check_alive sa
  check_alive rec
  fi

  # check if registered or not
  if [ "$mdb_reg_st" == "1" ] && [ "$mdb_oob_st" != "1" ]; then
    check_memory da_adaptor $mem_max_da_adaptor
    check_memory sa $mem_max_sa
    check_memory rec $mem_max_rec
  fi

  if [ "1" -eq "$DEV_LIST_DECODED" ]; then
    check_memory
  fi

  sleep $UNIT_CHECK_T
done
) &
