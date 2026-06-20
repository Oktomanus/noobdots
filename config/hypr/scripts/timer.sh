#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybartimer"
STATE_FILE="$STATE_DIR/state"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock -x 9 || { exit 1; }

END_TIME=0
NOTIFIED=0
ACTION="status"
OUTPUT="plain"

# Настройки шагов
DEFAULT_DURATION=600
STEP=300
STEP_MINUTE=60

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        read -r stored notif <"$STATE_FILE" || true
        END_TIME=$stored
        NOTIFIED=$notif
    fi
}

save_state() {
    if (( END_TIME > $(date +%s) )); then
        echo "$END_TIME $NOTIFIED" >"$STATE_FILE"
    else
        # Убиваем состояние полностью, если время вышло или сброшено
        rm -f "$STATE_FILE"
    fi
}

print_status() {
    local now=$(date +%s)

    # Если файла нет, значит таймер "убит"
    if [[ ! -f "$STATE_FILE" ]]; then
        if [[ "$OUTPUT" == "json" ]]; then
            echo '{"text":"","class":"idle"}'
        else
            echo "ready"
        fi
        return
    fi

    local remaining=$((END_TIME - now))

    if (( remaining <= 0 )); then
        # Если время вышло само (не было уведомлено)
        if (( NOTIFIED == 0 )); then
            notify-send -u critical -a "Timer" "⏰ Время вышло!"
        fi
        rm -f "$STATE_FILE"
        print_status # Рекурсивно выведет "ready"
    else
        local m=$((remaining / 60))
        local s=$((remaining % 60))
        local text=$(printf "%02d:%02d" "$m" "$s")

        if [[ "$OUTPUT" == "json" ]]; then
            printf '{"text":"%s","class":"running"}\n' "$text"
        else
            echo "$text"
        fi
    fi
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case "$1" in
        --start) ACTION="start" ;;
        --add)   ACTION="add" ;;
        --add1)  ACTION="add1" ;;
        --sub)   ACTION="sub" ;;
        --sub1)  ACTION="sub1" ;;
        --clear) ACTION="clear" ;;
        --json)  OUTPUT="json" ;;
    esac
    shift
done

load_state

case "$ACTION" in
    start)
        END_TIME=$(( $(date +%s) + DEFAULT_DURATION ))
        NOTIFIED=0
        save_state
        ;;
    add|add1)
        step=$([[ "$ACTION" == "add" ]] && echo "$STEP" || echo "$STEP_MINUTE")
        now=$(date +%s)
        (( END_TIME < now )) && END_TIME=$now
        END_TIME=$(( END_TIME + step ))
        NOTIFIED=0
        save_state
        ;;
    sub|sub1)
        step=$([[ "$ACTION" == "sub" ]] && echo "$STEP" || echo "$STEP_MINUTE")
        END_TIME=$(( END_TIME - step ))
        NOTIFIED=1 # Важно: если убавляем сами, помечаем как "уже уведомлен"
        save_state
        ;;
    clear)
        rm -f "$STATE_FILE"
        ;;
esac

if [[ "$ACTION" == "status" || "$ACTION" == "" ]]; then
    print_status
fi
