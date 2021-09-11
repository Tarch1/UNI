#!/bin/bash
while :
do
LOW="${LOW:-20}"
HALF_LOW=$(( LOW / 2 ))
LOWEST=$(( LOWEST / 2 ))
BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT*/capacity)
STATUS=$(cat /sys/class/power_supply/BAT*/status)

if [ $BATTERY_LEVEL -le $LOW -a $STATUS = Discharging ] 
then 
    if [ $BATTERY_LEVEL -le $HALF_LOW -a $STATUS = Discharging ] 
    then 
        if [ $BATTERY_LEVEL -le $LOWEST -a $STATUS = Discharging ] 
        then
            notify-send -t 5000 -u critical "Battery at $BATTERY_LEVEL%"
            SLEEPTIME=${SLEEPTIME:-30s}
        else
            notify-send -t 5000 -u normal "Battery at $BATTERY_LEVEL%"
            SLEEPTIME=${SLEEPTIME:-1m}
        fi
    else
        notify-send -t 5000 -u low "Battery at $BATTERY_LEVEL%"
        SLEEPTIME=${SLEEPTIME:-3m}
    fi
fi
sleep ${SLEEPTIME:-2m}
done
