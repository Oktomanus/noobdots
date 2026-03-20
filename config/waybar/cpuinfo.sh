#!/bin/bash

# 1. Получаем загрузку ЦП (максимально быстро через awk)
cpu_usage=$(awk '/^cpu / {usage=($2+$4)*100/($2+$4+$5); printf "%.0f", usage}' /proc/stat)

# 2. Ищем температуру (универсальный обход датчиков Intel и AMD)
cpu_temp="--"
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ]; then
        name=$(cat "$hwmon/name")
        # Проверяем на принадлежность к процессору (Intel или AMD)
        if [[ "$name" == "coretemp" || "$name" == "k10temp" ]]; then
            # Пробуем temp1, если пусто — temp2 (часто на ноутах)
            for i in 1 2 3; do
                if [ -f "$hwmon/temp${i}_input" ]; then
                    raw_temp=$(cat "$hwmon/temp${i}_input")
                    if [ "$raw_temp" -gt 0 ]; then
                        cpu_temp=$((raw_temp / 1000))
                        break 2 # Нашли — выходим из всех циклов
                    fi
                fi
            done
        fi
    fi
done

# 3. Финальный вывод для Waybar
echo " ${cpu_usage}%  ${cpu_temp}°C"
