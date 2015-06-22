#!/bin/sh

# OpenWRT fan control using RickStep and Chadster766's logic

# SLEEP_DURATION and CPU_TEMP_CHECK need to be multiples of each other
VERBOSE=1
EMERGENCY_COOLDOWN_DURATION=30
SLEEP_DURATION=5
CPU_TEMP_CHECK=20
DEFAULT_SPEED=100
EMERGENCY_COOLDOWN_TEMP_CHANGE=3                         

# DON'T MESS WITH THESE
LAST_FAN_SPEED=$DEFAULT_SPEED
EMERGENCY_COOLDOWN=0                
EMERGENCY_COOLDOWN_TIMER=0                         
ELAPSED_TIME=0 
CPU_TEMP=0
RAM_TEMP=0
WIFI_TEMP=0

# determine fan controller
if [ -d /sys/devices/pwm_fan ]; then
    FAN_CTRL=/sys/devices/pwm_fan/hwmon/hwmon0/pwm1
elif [ -d /sys/devices/platform/pwm_fan ]; then
    FAN_CTRL=/sys/devices/platform/pwm_fan/hwmon/hwmon0/pwm1
else
    exit 0
fi

# retreive new cpu, ram, and wifi temps
get_temps() {
    CPU_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon2/temp1_input` 
    RAM_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp1_input` 
    WIFI_TEMP=`cut -c1-2 /sys/class/hwmon/hwmon1/temp2_input`
}

# use this to make setting the fan a bit easier
#     set_fan WHAT VALUE
set_fan() {
    LAST_FAN_SPEED=`cat ${FAN_CTRL}`

    if [ $LAST_FAN_SPEED -ne $2 ]; then
        if [ $VERBOSE == 1 ]; then
            echo "setting fan to ${2} (${1}) ${FAN_CTRL}"
        fi

        # write the new speed to the fan controller
        echo $2 > ${FAN_CTRL}
    else
        if [ $VERBOSE == 1 ]; then
            echo "keeping fan speed at ${LAST_FAN_SPEED}"
        fi
    fi
}

# floating-point greater-than-or-equals-to using awk 'cause ash doesn't
# like floats. instead of this:
#     if [ $VALUE_1 >= $VALUE_2 ];
# use this:
#     if [ $(fge $VALUE_1 $VALUE_2) == 1 ];
float_ge() {
    awk -v n1=$1 -v n2=$2 "BEGIN { if ( n1 >= n2 ) exit 1; exit 0; }"
    echo $?
}

# start the emergency cooldown mode
start_emergency_cooldown() {
    if [ $VERBOSE == 1 ]; then
        echo
        echo "Starting Emergency Cooldown!"
    fi

    # toggle the cooldown bit to on and reset the timer
    EMERGENCY_COOLDOWN=1
    EMERGENCY_COOLDOWN_TIMER=$EMERGENCY_COOLDOWN_DURATION

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

            break
        fi
    done
}

# makes sure that the temperatures haven't fluctuated by more than 1.5 degrees
check_temp_change() {
    TEMP_CHANGE=$(($3 - $2));

    if [ $VERBOSE == 1 ]; then
        echo "${1} original temp: ${2} | new temp: ${3} | change: ${TEMP_CHANGE}"
    fi

    if [ $(float_ge $TEMP_CHANGE $EMERGENCY_COOLDOWN_TEMP_CHANGE) == 1 ]; then
       start_emergency_cooldown;

       continue;
    fi
}

# set fan speeds based on CPU temperatures
check_cpu_temp() {
    if [ $VERBOSE == 1 ] ; then
        echo "Checking CPU Temp ${CPU_TEMP}"
    fi

    if [ $CPU_TEMP -ge 70 ]; then
        set_fan CPU 255
    elif [ $(float_ge $CPU_TEMP 67.5) == 1 ]; then
        set_fan CPU 223
    elif [ $CPU_TEMP -ge 65 ]; then
        set_fan CPU 191
    elif [ $(float_ge $CPU_TEMP 62.5) == 1 ]; then
        set_fan CPU 159
    elif [ $CPU_TEMP -ge 60 ]; then
        set_fan CPU 127
    elif [ $CPU_TEMP -ge 55 ]; then
        set_fan CPU 95
    elif [ $CPU_TEMP -ge 50 ]; then
        set_fan CPU 63
    fi
}

# start the fan initially to $DEFAULT_SPEED
set_fan START $DEFAULT_SPEED

# and get the initial system temps
get_temps

# the main program loop:
# - look at load averages every $SLEEP_DURATION seconds
# - look at temperature deltas every $SLEEP_DURATION seconds
# - look at raw cpu temp every $CPU_TEMP_CHECK seconds
while true ; do

    # handle emergency cooldown stuff
    if [ $EMERGENCY_COOLDOWN == 1 ]; then

        # reduce the number of seconds left in emergency cooldown mode
        EMERGENCY_COOLDOWN_TIMER=$((${EMERGENCY_COOLDOWN_TIMER} - 5))

        # do we still need to be in cooldown?
        if [ $EMERGENCY_COOLDOWN_TIMER -le 0 ]; then

            set_fan LAST $LAST_FAN_SPEED                              

            EMERGENCY_COOLDOWN=0                                      

            if [ $VERBOSE == 1 ]; then
                echo "Exiting Emergency Cooldown Mode!"
                echo
            fi

        else
            if [ $VERBOSE == 1 ]; then
                echo "Still in Emergency Cooldown. ${EMERGENCY_COOLDOWN_TIMER} seconds left."
            fi

            sleep $SLEEP_DURATION

            continue
        fi
    fi

    # save the previous temperatures                                    
    LAST_CPU_TEMP=$CPU_TEMP                                            
    LAST_RAM_TEMP=$RAM_TEMP                                                      
    LAST_WIFI_TEMP=$WIFI_TEMP                                                 

    # and re-read the current temperatures
    get_temps 

    # check the load averages
    check_load

    # check to see if the cpu, ram, or wifi temps have spiked
    check_temp_change CPU $CPU_TEMP $LAST_CPU_TEMP
    check_temp_change RAM $RAM_TEMP $LAST_RAM_TEMP
    check_temp_change WIFI $WIFI_TEMP $LAST_WIFI_TEMP

    # check the raw CPU temps every $CPU_TEMP_CHECK seconds...
    if [ $(( $ELAPSED_TIME % $CPU_TEMP_CHECK )) == 0 ]; then
        check_cpu_temp
    fi

    # wait $SLEEP_DURATION seconds and do this again
    if [ $VERBOSE == 1 ]; then
        echo "waiting ${SLEEP_DURATION} seconds..."
        echo
    fi

    sleep $SLEEP_DURATION;

    ELAPSED_TIME=$(($ELAPSED_TIME + $SLEEP_DURATION))
done
