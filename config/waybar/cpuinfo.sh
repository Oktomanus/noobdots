#!/bin/bash

# Get CPU usage (average across all cores)
cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')

# Get CPU temperature
temp=$(cat /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
temp=$((temp / 1000))

# Output formatted string
echo " ${cpu_usage}%  ${temp}°C"
