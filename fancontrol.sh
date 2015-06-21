#!/bin/sh

# OpenWRT fan control using RickStep's logic

# set this to 1 for some debugging output
VERBOSE=1

# get some initial readings
CPU_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon2/temp1_input`        
RAM_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp1_input`   
WIFI_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp2_input`

EMERGENCY_COOLDOWN=0
EMERGENCY_COOLDOWN_TIMER=0
LOOP_COUNTER=0

# determine fan controller
if [ -d /sys/devices/pwm_fan ]; then
    FAN_CTRL=/sys/devices/pwm_fan/hwmon/hwmon0/pwm1
elif [ -d /sys/devices/platform/pwm_fan ]; then
    FAN_CTRL=/sys/devices/platform/pwm_fan/hwmon/hwmon0/pwm1
else
    exit 0
fi

# use this to make setting the fan a bit easier
#     set_fan WHAT VALUE
set_fan() {
    if [ $VERBOSE == 1 ]; then
        echo "setting fan to ${2} (${1}) ${FAN_CTRL}"
    fi

    echo $2 > ${FAN_CTRL}
}

# floating-point greater-than-or-equals-to using awk 'cause ash doesn't
# like floats. instead of this:
#     if [ $VALUE_1 >= $VALUE_2 ];
# use this:
#     if [ $(fge $VALUE_1 $VALUE_2) ];
float_ge() {
    awk -v n1=$1 -v n2=$2 "BEGIN { if ( n1 >= n2 ) exit 1; exit 0; }"
    echo $?
}

# start the emergency cooldown mode
start_emergency_cooldown() {
    if [ $VERBOSE == 1 ]; then
        echo "Starting Emergency Cooldown!"
    fi

    # toggle the cooldown bit to on and reset the timer
    EMERGENCY_COOLDOWN=1
    EMERGENCY_COOLDOWN_TIMER=30

    set_fan EMERGENCY 255
}              

# check for load averages above 1.0
check_load() {
    # loop over each load value (1 min, 5 min, 15 min)
    for LOAD in `cat /proc/loadavg | cut -d " " -f1,2,3`; do
        if [ $VERBOSE == 1 ]; then
            echo "Checking Load ${LOAD}"
        fi

        # trigger the emergency cooldown if we're using more than 1 core
        if [ $(float_ge $LOAD 1.0) == 1 ]; then
            start_emergency_cooldown
        fi
    done
}

# makes sure that the temperatures haven't fluctuated by more than 1.5 degrees
check_temp_delta() {
    TEMP_DELTA=$(($3 - $2));

    if [ $VERBOSE == 1 ]; then
        echo "${1} original temp: ${2} | new temp: ${3} | delta: ${TEMP_DELTA}"
    fi

    if [ $(float_ge $TEMP_DELTA 1.5) == 1 ]; then
       start_emergency_cooldown;
    fi
}

# set fan speeds based on CPU temperatures
check_cpu_temp() {
    if [ $VERBOSE == 1 ] ; then
        echo "Checking CPU Temp ${CPU_TEMP}"
    fi

    if [ $CPU_TEMP -ge 70 ]; then
        set_fan CPU 255
    elif [ $(float_ge CPU_TEMP 67.5) ]; then
        set_fan CPU 223
    elif [ $CPU_TEMP -ge 65 ]; then
        set_fan CPU 191
    elif [ $(float_ge $CPU_TEMP 62.5) ]; then
        set_fan CPU 159
    elif [ $CPU_TEMP -ge 60 ]; then
        set_fan CPU 127
    elif [ $CPU_TEMP -ge 55 ]; then
        set_fan CPU 95
    elif [ $CPU_TEMP -ge 50 ]; then
        set_fan CPU 63
    fi
}

# start the fan initially at 100
set_fan START 100

# the main program loop:
# - look at load averages every 5 seconds
# - look at temperature deltas every 5 seconds
# - look at raw cpu temp every 20 seconds
while true ; do
    LOOP_COUNTER=$(($LOOP_COUNTER + 1));

    # save the previous temperatures
    LAST_CPU_TEMP=$CPU_TEMP
    LAST_RAM_TEMP=$RAM_TEMP
    LAST_WIFI_TEMP=$WIFI_TEMP

    # and re-read the current temperatures
    CPU_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon2/temp1_input`
    RAM_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp1_input`
    WIFI_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp2_input`

    # handle emergency cooldown stuff
    if [ EMERGENCY_COOLDOWN == 1 ]; then

        # reduce the number of seconds left in emergency cooldown mode
        EMERGENCY_COOLDOWN_TIMER=$(($EMERGENCY_COOLDOWN_TIMER} - 5))

        # do we still need to be in cooldown?
        if [ $EMERGENCY_COOLDOWN_TIMER <= 0 ]; then

            if [ $VERBOSE == 1 ]; then
                echo "Exiting Emergency Cooldown Mode!"
            fi

            EMERGENCY_COOLDOWN=0
        else
            sleep 5

            continue
        fi
    fi

    # check the load averages
    check_load

    # check to see if the cpu, ram, or wifi temps have spiked
    check_temp_delta CPU $CPU_TEMP $LAST_CPU_TEMP
    check_temp_delta RAM $RAM_TEMP $LAST_RAM_TEMP
    check_temp_delta WIFI $WIFI_TEMP $LAST_WIFI_TEMP

    # check the raw CPU temps every 20 seconds
    if [ $(($LOOP_COUNTER % 4)) == 0 ] ; then
        check_cpu_temp;
    fi

    # wait 5 seconds and do this again
    if [ $VERBOSE == 1 ]; then
        echo "waiting 5 seconds..."
        echo
    fi

    sleep 5;
done
