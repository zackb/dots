#!/bin/bash

# Cache the CPU model name once
cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
if [[ -z "$cpu_model" ]]; then
    cpu_model="Unknown CPU"
fi

declare -A prev_idle
declare -A prev_total

# Read stat once to initialize previous values
while read -r line; do
    if [[ $line =~ ^cpu ]]; then
        read -r -a cpu_data <<< "$line"
        cpu_name="${cpu_data[0]}"
        idle=$(( ${cpu_data[4]} + ${cpu_data[5]} ))
        total=0
        for val in "${cpu_data[@]:1}"; do
            total=$(( total + val ))
        done
        prev_idle[$cpu_name]=$idle
        prev_total[$cpu_name]=$total
    fi
done < /proc/stat

while true; do
    # Memory usage
    mem=$(free | awk '/Mem:/ {printf "%d", $3/$2*100}')
    
    # Disk usage
    disk=$(df / | awk 'NR==2 {print int($5)}')
    
    # Temperature
    temp=0
    for tz in /sys/class/thermal/thermal_zone*; do
        if [[ -f "$tz/type" ]] && [[ $(cat "$tz/type") == "x86_pkg_temp" || $(cat "$tz/type") == "acpitz" || $(cat "$tz/type") == "cpu_thermal" || $(cat "$tz/type") == "k10temp" ]]; then
            tval=$(cat "$tz/temp" 2>/dev/null)
            if [[ -n "$tval" ]]; then
                temp=$(( tval / 1000 ))
                break
            fi
        fi
    done
    if [[ $temp -eq 0 ]]; then
        tval=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$tval" ]]; then
            temp=$(( tval / 1000 ))
        fi
    fi

    cores_data=""
    overall_cpu=0
    
    while read -r line; do
        if [[ $line =~ ^cpu ]]; then
            read -r -a cpu_data <<< "$line"
            cpu_name="${cpu_data[0]}"
            idle=$(( ${cpu_data[4]} + ${cpu_data[5]} ))
            total=0
            for val in "${cpu_data[@]:1}"; do
                total=$(( total + val ))
            done
            
            diff_idle=$(( idle - ${prev_idle[$cpu_name]:-0} ))
            diff_total=$(( total - ${prev_total[$cpu_name]:-0} ))
            
            if [ $diff_total -eq 0 ]; then
                pct=0
            else
                pct=$(( 100 * (diff_total - diff_idle) / diff_total ))
            fi
            
            if [ $pct -lt 0 ]; then pct=0; fi
            if [ $pct -gt 100 ]; then pct=100; fi
            
            if [ "$cpu_name" = "cpu" ]; then
                overall_cpu=$pct
            else
                freq=$(( $(cat /sys/devices/system/cpu/$cpu_name/cpufreq/scaling_cur_freq 2>/dev/null || echo 0) / 1000 ))
                cores_data="$cores_data ${pct}:${freq}"
            fi
            
            prev_idle[$cpu_name]=$idle
            prev_total[$cpu_name]=$total
        fi
    done < /proc/stat
    
    # Print: cpu_model;overall_cpu;mem;disk;temp;cores_data
    echo "${cpu_model};${overall_cpu};${mem};${disk};${temp};${cores_data# }"
    
    sleep 3
done
