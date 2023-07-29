export LD_LIBRARY_PATH=/mnt/mtd/lib:$LD_LIBRARY_PATH
export PATH=$PATH:/mnt/mtd/

COLOR_NORMAL="\e[0;39m"
COLOR_RED="\e[1;31m"
COLOR_GREEN="\e[1;32m"
COLOR_YELLOW="\e[1;33m"
COLOR_BLUE="\e[1;34m"

# Replace with custom encrypted password, but keep a backup
if [ -f "/mnt/mtd/shadow" ];then
    # Keep a backup of the original shadow, but never overwrite it
    if [ ! -f /mnt/conf/shadow.orig ];then
        cp /mnt/conf/shadow /mnt/conf/shadow.orig
    fi
    mv /mnt/mtd/shadow /mnt/conf/shadow
    # Remove the new shadow to prevent doing this on every bootup and replacing any user change of the root password
fi

if [ -f "/mnt/conf/passwd" ];then
    if [ -f "/mnt/mtd/passwd" ];then
        rm /mnt/mtd/passwd
    fi
else
    mv /mnt/mtd/passwd /mnt/conf
fi

if [ -f "/mnt/conf/shadow" ];then
    if [ -f "/mnt/mtd/shadow" ];then
        rm /mnt/mtd/shadow
    fi
else
    mv /mnt/mtd/shadow /mnt/conf
fi

function gpio_set_value()
{
    echo "set gpio$1 value to $2 "
    echo $1 > /sys/class/gpio/export
    echo out > /sys/class/gpio/gpio$1/direction
    echo $2 > /sys/class/gpio/gpio$1/value
}

############################get device config start####################################
sensorName=""
config_file_name=""
original_devtype=""
devtype_pref=""
devtype=""

isNeedPIR=0

if [ ! -d "/mnt/mtd/product_type" ];then
    mkdir -p /mnt/mtd/product_type
    touch /mnt/mtd/product_type/DLINK_E968R7F_DCS6100LH
fi

sensorName="jxf37"
devtype="RT3906_96K"
############################get device config end####################################


############################wifi start####################################
echo "=========wifi power on========="
############################wifi end####################################

############################speaker start##########################################
echo "=============speaker disable================="
if [ "RT3906_97A" == $devtype ] || [ "RTS3906N_97A_R72_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" speaker power is gpio 18,low valid"${COLOR_NORMAL}
	gpio_set_value 18 1
elif [ "RT3906_980" == $devtype ] || [ "RT3906_980_R7C_CFG" == $devtype ] ||
     [ "RT3906_977" == $devtype ] || [ "RT3906_977_R7C_CFG" == $devtype ] ||
     [ "RT3906_97U" == $devtype ] || [ "RT3906_97U_R72_CFG" == $devtype ] ||
     [ "RT3906_966" == $devtype ] || [ "RT3906_966_R02_CFG" == $devtype ] ||
     [ "RT3906_95A" == $devtype ] || [ "RT3906_95A_R7C_CFG" == $devtype ] ||
     [ "RT3906_952" == $devtype ] || [ "RT3906_952_R42_CFG" == $devtype ] ||
     [ "RT3906_96F" == $devtype ] || [ "RT3906_96F_R7F_CFG" == $devtype ] ||
     [ "RT3906_96K" == $devtype ] || [ "RT3906_96K_R7F_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" speaker power is gpio 18,high valid"${COLOR_NORMAL}
	gpio_set_value 18 0
else
	echo -e ${COLOR_GREEN}$devtype"speaker unsupport devtype"${COLOR_NORMAL}
fi
############################speaker end###########################################


####################adapter led start #################################
##################TUYA red on######################
if [ "RT3906_97A" == $devtype ] || [ "RTS3906N_97A_R72_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" led red is gpio 6,blue is gpio 22"${COLOR_NORMAL}
	gpio_set_value 6 0
	gpio_set_value 22 1 
elif [ "RTS3906_980" == $devtype ] || [ "RT3906_980_R7C_CFG" == $devtype ] || 
     [ "RT3906_977" == $devtype ] || [ "RT3906_977_R7C_CFG" == $devtype ] ||
     [ "RT3906_97U" == $devtype ] || [ "RT3906_97U_R72_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" red is gpio 16,blue is gpio 22"${COLOR_NORMAL}
	gpio_set_value 16 0
	gpio_set_value 22 1 
elif [ "RT3906_95A" == $devtype ] || [ "RT3906_95A_R7C_CFG" == $devtype ] ||
     [ "RT3906_952" == $devtype ] || [ "RT3906_952_R42_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" red is gpio 8,blue is gpio 22"${COLOR_NORMAL}
	gpio_set_value 8 0
	gpio_set_value 22 1 
elif [ "RT3906_966" == $devtype ] || [ "RT3906_966_R02_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" red is gpio 22,blue is gpio 8"${COLOR_NORMAL}
	gpio_set_value 22 0
	gpio_set_value 8 1 
elif [ "RT3906_96K" == $devtype ] || [ "RT3906_96K_R7F_CFG" == $devtype ] ||
     [ "RT3906_96F" == $devtype ] || [ "RT3906_96F_R7F_CFG" == $devtype ] ;then
	echo -e ${COLOR_GREEN}$devtype" red is gpio 11,blue is gpio 6"${COLOR_NORMAL}
	gpio_set_value 11 0
	gpio_set_value 6 1 
else
	echo -e ${COLOR_GREEN}$devtype"led unsupport devtype"${COLOR_NORMAL}
fi

####################adapter led end #################################

############################media start####################################
if [ "" != "$sensorName" ];then
        echo -e ${COLOR_GREEN}"to load3518e drivers,sensor is "$sensorName${COLOR_NORMAL}
		ln -sf /mnt/mtd/lib/firmware/sensor_fw_$sensorName"".bin /mnt/mtd/lib/firmware/isp.fw 
else
        echo -e  "\e[1;33m""boot.sh:""\e[0;31m""Serious error!!!!I don't known which sensor to config,some errors may occur!!!""\e[0m"
		ln -sf /mnt/mtd/lib/firmware/sensor_fw_jxf23.bin /mnt/mtd/lib/firmware/isp.fw 
fi
echo /mnt/mtd/lib/firmware/isp.fw > /sys/class/rts_camera/rtsmcu/device/loadfw
############################media end####################################


############################pir driver start####################################
if [ $devtype ];then
        if [ "RT3906_97A" == $devtype ] || [ "RTS3906N_97A_R72_CFG" == $devtype ];then 
                echo -e ${COLOR_GREEN}"if device type is 975||97A||97C,need to load PIR.ko"${COLOR_NORMAL}
                insmod /mnt/mtd/lib/modules/PIR.ko
        fi
else
        echo -e ${COLOR_RED}"device type is null,not to load PIR.ko"${COLOR_NORMAL}
fi
############################pir driver end####################################

############################system init start####################################
rm -rf /mydlink/cert
ln -s  /mnt/conf/cert /mydlink/cert
rm -rf /mydlink/config
ln -s  /mnt/conf/config /mydlink/config
rm -rf /mydlink/lib/libssl.so
rm -rf /mydlink/lib/libssl.so.1.0.0
ln -s /mnt/mtd/lib/libssl.so.1.0.0 /mydlink/lib/libssl.so
ln -s /mnt/mtd/lib/libssl.so.1.0.0 /mydlink/lib/libssl.so.1.0.0
cp /mnt/mtd/hosts /var/conf/

echo 3 > /proc/sys/vm/drop_caches > /dev/null
/etc/init.d/S50telnet stop
echo 2048 > /proc/sys/vm/min_free_kbytes

############################system init end####################################

############################application start####################################
cd /
/mnt/mtd/socket_system_server > /var/log/socket_system_server.log 2>&1 & 

echo "sleep 3 seconds wait sd card!!!"
sleep 3

echo "If you want to run app by yourself, please input q "
read -t 2 -p "=======================Press q -> Entry ?" exit_cmd
if [ "$exit_cmd" == "q" ] ; then
        exit
fi

/mnt/mtd/daemon > /var/log/daemon.log 2>&1 &
/mnt/mtd/auto_web_recover.sh &
date -s "2000-1-1 00:00:00"

# Parse if Telnet daemon should be started
if grep -q -i "Telnet" /mnt/conf/SystemConfig.ini; then
        start_telnet=$(grep -i Telnet /mnt/conf/SystemConfig.ini | awk {'print($3)'})
        if [[ $start_telnet -eq 1 ]]; then
                echo "Starting telnet"
                /etc/init.d/S50telnet start
        fi
fi

############################application end####################################
