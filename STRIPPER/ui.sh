#!/bin/sh
# STRIPPER: portable progress/status reporting for BusyBox/POSIX sh.
# Prefix temporary names because POSIX shell functions have global variables.
progress_bar() {
    pb_done=$1
    pb_target=$2
    pb_label=$3
    [ "$pb_target" -gt 0 ] || pb_target=1
    [ "$pb_done" -ge 0 ] || pb_done=0
    [ "$pb_done" -le "$pb_target" ] || pb_done=$pb_target
    pb_percent=$((pb_done * 100 / pb_target))
    pb_fill=$((pb_done * 24 / pb_target))
    pb_empty=$((24 - pb_fill))
    pb_blocks=
    pb_spaces=
    pb_n=0
    while [ "$pb_n" -lt "$pb_fill" ]; do pb_blocks="${pb_blocks}#"; pb_n=$((pb_n+1)); done
    pb_n=0
    while [ "$pb_n" -lt "$pb_empty" ]; do pb_spaces="${pb_spaces}-"; pb_n=$((pb_n+1)); done
    printf '  [%s%s] %3d%% (%d/%d) %s\n' "$pb_blocks" "$pb_spaces" "$pb_percent" "$pb_done" "$pb_target" "$pb_label"
}
progress_step() {
    printf '\n[STEP %s/%s] %s\n' "$1" "$2" "$3"
}
# A periodic pulse avoids false invented download percentages.
fetch_with_feedback() {
    feedback_purpose=$1
    feedback_source=$2
    feedback_destination=$3
    printf '  Connecting for %s ...\n' "$feedback_purpose"
    fetch "$feedback_source" "$feedback_destination" &
    feedback_pid=$!
    feedback_ticks=0
    while kill -0 "$feedback_pid" 2>/dev/null; do
        sleep 1
        if kill -0 "$feedback_pid" 2>/dev/null; then
            feedback_ticks=$((feedback_ticks+1))
            printf '  ... %s still in progress (%ds)\n' "$feedback_purpose" "$feedback_ticks"
        fi
    done
    if wait "$feedback_pid"; then
        printf '  Received %s (%s bytes)\n' "$feedback_purpose" "$(wc -c < "$feedback_destination" | tr -d ' ')"
        return 0
    fi
    printf '  Download failed: %s\n' "$feedback_purpose" >&2
    return 1
}
