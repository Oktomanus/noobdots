#!/usr/bin/env bash
set -euo pipefail

# --- КОНФИГУРАЦИЯ ---
DEFAULT_DURATION=600   # 10 минут
STEP=300               # +/- 5 минут
STEP_MINUTE=60         # +/- 1 минута

# Директория для хранения состояния (в оперативной памяти)
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybartimer"
STATE_FILE="$STATE_DIR/state"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"

# Блокировка, чтобы избежать конфликтов при одновременном вызове (клик + поллинг)
exec 9>"$LOCK_FILE"
flock -x 9 || { echo "timer: ошибка блокировки" >&2; exit 1; }

END_TIME=0
NOTIFIED=0
OUTPUT="plain"
ACTION="status"

usage() {
    cat <<EOF
Использование: $(basename "$0") [--start|--add|--add1|--sub|--sub1|--clear|--status] [--json]
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start) ACTION="start" ;;
            --add) ACTION="add" ;;
            --add1) ACTION="add1" ;;
            --sub|--subtract) ACTION="sub" ;;
            --sub1) ACTION="sub1" ;;
            --clear|--reset) ACTION="clear" ;;
            --status|"") ACTION="status" ;;
            --json) OUTPUT="json" ;;
            -h|--help) usage; exit 0 ;;
            *)
                echo "Неизвестный флаг: $1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        read -r stored notif <"$STATE_FILE" || true
        [[ "$stored" =~ ^[0-9]+$ ]] && END_TIME="$stored" || END_TIME=0
        [[ "$notif" == "1" ]] && NOTIFIED=1 || NOTIFIED=0
    fi
}

save_state() {
    if (( END_TIME > 0 )); then
        echo "$END_TIME $NOTIFIED" >"$STATE_FILE"
    else
        rm -f "$STATE_FILE"
    fi
}

now_seconds() {
    date +%s
}

remaining_seconds() {
    local now remaining
    now=$(now_seconds)
    remaining=$((END_TIME - now))
    (( remaining > 0 )) && echo "$remaining" || echo 0
}

format_time() {
    local total=$1
    local h m s
    h=$((total / 3600))
    m=$(((total % 3600) / 60))
    s=$((total % 60))
    if (( h > 0 )); then
        printf "%02d:%02d:%02d" "$h" "$m" "$s"
    else
        printf "%02d:%02d" "$m" "$s"
    fi
}

print_status() {
    local remaining
    remaining=$(remaining_seconds)

    # Уведомление, если время вышло
    if (( remaining <= 0 && END_TIME > 0 && NOTIFIED == 0 )); then
        notify-send -u critical -a "Timer" "⏰ Время вышло!"
        NOTIFIED=1
        END_TIME=0
        save_state
        remaining=0
    fi

    if (( remaining > 0 )); then
        local text="$(format_time "$remaining")"
        if [[ "$OUTPUT" == "json" ]]; then
            printf '{"text":"%s","class":"running","alt":"running"}\n' "$text"
        else
            echo "$text"
        fi
    else
        if [[ "$OUTPUT" == "json" ]]; then
            printf '{"text":"","class":"idle","alt":"idle"}\n'
        else
            echo "ready"
        fi
    fi
}

start_timer() {
    END_TIME=$(( $(now_seconds) + DEFAULT_DURATION ))
    NOTIFIED=0
    save_state
}

add_time() {
    local step=${1:-$STEP}
    local now remaining
    now=$(now_seconds)
    remaining=$(remaining_seconds)

    if (( remaining == 0 )); then
        END_TIME=$(( now + step ))
    else
        END_TIME=$(( END_TIME + step ))
    fi
    NOTIFIED=0
    save_state
}

sub_time() {
    local step=${1:-$STEP}
    local now remaining
    now=$(now_seconds)
    remaining=$(remaining_seconds)

    if (( remaining > 0 )); then
        END_TIME=$(( END_TIME - step ))
        (( END_TIME <= now )) && END_TIME=0
    fi
    NOTIFIED=0
    save_state
}

clear_timer() {
    END_TIME=0
    NOTIFIED=0
    save_state
}

# --- ВЫПОЛНЕНИЕ ---

parse_args "$@"
load_state

case "$ACTION" in
    start) start_timer ;;
    add)   add_time "$STEP" ;;
    add1)  add_time "$STEP_MINUTE" ;;
    sub)   sub_time "$STEP" ;;
    sub1)  sub_time "$STEP_MINUTE" ;;
    clear) clear_timer ;;
    status) ;;
esac

# Всегда выводим статус в конце для обновления Waybar
print_status
