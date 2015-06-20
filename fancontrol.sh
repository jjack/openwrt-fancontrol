#!/bin/sh

# OpenWRT fan control using RickStep's logic

VERBOSE=1

CPU_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon2/temp1_input`        
DDR_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp1_input`   
WIFI_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp2_input`
EMERGENCY_COOLDOWN=0
EMERGENCY_COOLDOWN_TIMELEFT=0
LOOP_COUNTER=1;

# determine fan controller
if [ -d /sys/devices/pwm_fan ]; then
    FAN_CTRL=/sys/devices/pwm_fan/hwmon/hwmon0/pwm1
elif [ -d /sys/devices/platform/pwm_fan ]; then
    FAN_CTRL=/sys/devices/platform/pwm_fan/hwmon/hwmon0/pwm1
else
    exit 0
fi

# simple function to make setting the fan a little nicer
setFan() {
    if [ $VERBOSE == 1 ]; then
        echo "setFan: $1 ${FAN_CTRL}"
    fi

    echo $1 > ${FAN_CTRL}
}

# floating-point greater-than-or-equals-to
fge() {
    awk -v n1=$1 -v n2=$2 'BEGIN{ if (n1>=n2) exit 1; exit 0}';
    echo $?;
}

# trigger the emergency cooldown mode
startEmergencyCooldown() {
    if [ $VERBOSE == 1 ]; then
        echo "Starting Emergency Cooldown!"
    fi

    EMERGENCY_COOLDOWN=1; 
    EMERGENCY_COOLDOWN_TIMELEFT=30;
    setFan 255;
}              

# check for load averages above 1.0
checkLoads() {
    # loop over each load value (1 min, 5 min, 15 min)
    for LOAD in `cat /proc/loadavg | cut -d " " -f1,2,3`; do
        if [ $VERBOSE == 1 ]; then
            echo "Checking Load ${LOAD}"
        fi

        # trigger the emergency cooldown if we're using more than 1 core
        if [ $(fge $LOAD 1.0) == 1 ]; then
            startEmergencyCooldown;
        fi
    done
}

# makes sure that the temperatures haven't fluctuated by more than 1 degrees
checkTempDelta() {
    TEMP_DELTA=$(($2 - $1));

    if [ $VERBOSE == 1 ]; then
        echo "Original Temp: $1 | New Temp: $2 | Delta: $TEMP_DELTA"
    fi

    if [ $(fge $TEMP_DELTA 1.5) == 1 ]; then
       startEmergencyCooldown;
    fi
}

# set fan speeds based on CPU temperatures
checkCPUTemp() {
    if [ $VERBOSE == 1 ] ; then
        echo "Checking CPU Temp ${CPU_TEMP}"
    fi

    if [ $CPU_TEMP -ge 70 ]; then
        setFan 255;
    elif [ $(fge CPU_TEMP 67.5) ]; then
        setFan 223;
    elif [ $CPU_TEMP -ge 65 ]; then
        setFan 191;
    elif [ $(fge $CPU_TEMP 62.5) ]; then
        setFan 159;
    elif [ $CPU_TEMP -ge 60 ]; then
        setFan 127;
    elif [ $CPU_TEMP -ge 55 ]; then
        setFan 95;
    elif [ $CPU_TEMP -ge 50 ]; then
        setFan 63;
    fi
}

while true ; do
    # save the previous temperatures
    LAST_CPU_TEMP=$CPU_TEMP;
    LAST_DDR_TEMP=$DDR_TEMP;
    LAST_WIFI_TEMP=$WIFI_TEMP;

    # re-read the temps
    CPU_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon2/temp1_input`
    DDR_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp1_input`
    WIFI_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp2_input`

    # check for the emergency cooldown mode
    if [ EMERGENCY_COOLDOWN == 1 ]; then
        # reduce the number of seconds left
        EMERGENCY_COOLDOWN_TIMELEFT=$(($EMERGENCY_COOLDOWN_TIMELEFT} - 5));

        # do we still need to be in cooldown?
        if [ EMERGENCY_COOLDOWN_TIMELEFT <= 0]; then
            EMERGENCY_COOLDOWN = 0;
        else
            sleep 5;
            continue;
        fi
    fi

    # check the load averages > 1.0
    checkLoads;

    # make sure that the CPU, DDR, and WiFI temps haven't spiked
    checkTempDelta $CPU_TEMP $LAST_CPU_TEMP;
    checkTempDelta $DDR_TEMP $LAST_DDR_TEMP;
    checkTempDelta $WIFI_TEMP $LAST_WIFI_TEMP;

    # check the raw CPU temps every 20 seconds
    if [ $(($LOOP_COUNTER % 4)) == 0 ] ; then
        checkCPUTemp;
    fi

    # wait 5 seconds and do this again
    sleep 5;
    LOOP_COUNTER=$(($LOOP_COUNTER + 1));
done
