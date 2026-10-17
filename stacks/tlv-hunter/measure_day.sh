#!/usr/bin/env bash
# One measured day (the TLV repo's docs/DEPLOY.md §5, Phase 3's DoD 6). Not the Phase 5 scheduler.
#
#   bash measure_day.sh start     start it in the background (survives closing the SSH session)
#   bash measure_day.sh status    is it running? what did it do last?
#   bash measure_day.sh log       the log's last 40 lines (bash measure_day.sh log 100 for more)
#   bash measure_day.sh stop      stop early: the command running now finishes first
#   bash measure_day.sh totals    the day's totals from the log (bash measure_day.sh totals <log file>)
#
# For 24 hours from its start: a slot every 30 minutes, at :00 and :30, except slots starting
# between 00:00 and 07:00 Israel time. In each slot, one after the other, never two at once
# (#140): run_once, then classify_pending --cap 0.05. A slot that runs long delays the next one,
# which starts right after it. A failed command is logged and the day goes on (a failed run moves
# no watermark, so the next run covers its window); 3 failed collection runs in a row stop it.
# PAID: every slot calls Apify and OpenAI. Do not run any other job command while it runs.
set -u

cd "$(dirname "$0")" || exit 1

ZONE="Asia/Jerusalem"
MEASURE_DIR="appdata/measure"
PID_FILE="$MEASURE_DIR/measure_day.pid"
SLOT_SECONDS="${MEASURE_SLOT_SECONDS:-1800}"   # the override is for testing the script only
DAY_SECONDS="${MEASURE_DAY_SECONDS:-86400}"    # the override is for testing the script only
QUIET_FROM=0                                    # quiet hours: a slot starting 00:00-06:59 is skipped
QUIET_UNTIL=7
CLASSIFY_CAP="0.05"
MAX_FAILED_COLLECTIONS=3
COMPOSE="${MEASURE_COMPOSE:-docker compose}"   # the override is for testing the script only

israel() { TZ="$ZONE" date -d "@$1" "+$2"; }
now() { date +%s; }

running_pid() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid="$(cat "$PID_FILE")"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}

check_zone() {
    # Without the zone's data, `date` falls back to UTC without a word: refuse instead.
    local abbreviation
    abbreviation="$(TZ="$ZONE" date +%Z)"
    if [[ "$abbreviation" != "IST" && "$abbreviation" != "IDT" ]]; then
        echo "refused: the time zone $ZONE is not known on this machine (got '$abbreviation')" >&2
        exit 1
    fi
}

in_quiet_hours() {
    local hour
    hour=$((10#$(israel "$1" %H)))
    ((hour >= QUIET_FROM && hour < QUIET_UNTIL))
}

next_boundary() {   # the first :00 or :30 strictly after $1
    echo $(( ($1 / SLOT_SECONDS + 1) * SLOT_SECONDS ))
}

STOP=0
SLEEP_PID=""
on_signal() { STOP=1; [[ -n "$SLEEP_PID" ]] && kill "$SLEEP_PID" 2>/dev/null; }

wait_until() {   # sleeps until $1; a stop request ends the wait at once
    local seconds=$(( $1 - $(now) ))
    ((seconds > 0)) || return 0
    sleep "$seconds" &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null
    SLEEP_PID=""
}

job() {   # one job command, its full output and its exit code appended to the log
    local name="$1"
    shift
    echo "--- $name, started $(israel "$(now)" '%F %T %Z')" >>"$LOG"
    # In the foreground: a stop request waits for it to finish (the store is never left half-written).
    $COMPOSE run --rm -T jobs python -m "tlv_hunter.jobs.$name" "$@" </dev/null >>"$LOG" 2>&1
    local code=$?
    echo "--- $name, exit $code, ended $(israel "$(now)" '%F %T %Z')" >>"$LOG"
    return "$code"
}

run_day() {
    check_zone
    mkdir -p "$MEASURE_DIR"
    local pid
    if pid="$(running_pid)" && [[ "$pid" != "$$" ]]; then
        echo "refused: already running (pid $pid)" >&2
        exit 1
    fi
    echo $$ >"$PID_FILE"
    trap 'rm -f "$PID_FILE"' EXIT
    trap on_signal TERM INT

    local started end slot failed=0 quiet_logged=0
    started="$(now)"
    end=$((started + DAY_SECONDS))
    LOG="$MEASURE_DIR/$(israel "$started" %F).log"
    {
        echo "===== measured day started $(israel "$started" '%F %T %Z'), ends $(israel "$end" '%F %T %Z')"
        echo "===== pid $$; a slot every $((SLOT_SECONDS / 60)) minutes; quiet ${QUIET_FROM}:00-${QUIET_UNTIL}:00 $ZONE; classify cap \$$CLASSIFY_CAP"
    } >>"$LOG"

    slot="$(next_boundary "$started")"
    while ((STOP == 0)); do
        wait_until "$slot"
        ((STOP == 0)) || break
        if ((slot >= end)); then
            echo "===== 24 hours done $(israel "$(now)" '%F %T %Z')" >>"$LOG"
            break
        fi
        if in_quiet_hours "$slot"; then
            if ((quiet_logged == 0)); then
                echo "===== quiet hours from $(israel "$slot" '%F %H:%M'): no slot until ${QUIET_UNTIL}:00" >>"$LOG"
                quiet_logged=1
            fi
            slot="$(next_boundary "$slot")"
            continue
        fi
        quiet_logged=0

        echo "===== slot $(israel "$slot" '%F %H:%M %Z'), started $(israel "$(now)" '%T')" >>"$LOG"
        if job run_once; then
            failed=0
        else
            failed=$((failed + 1))
            echo "===== collection failed ($failed in a row)" >>"$LOG"
            if ((failed >= MAX_FAILED_COLLECTIONS)); then
                echo "===== stopped: $MAX_FAILED_COLLECTIONS failed collection runs in a row" >>"$LOG"
                break
            fi
        fi
        # A stop request during run_once ends the day there: its posts wait for the next
        # classify_pending, by hand or another day.
        ((STOP == 0)) && job classify_pending --cap "$CLASSIFY_CAP"

        # The next :00 or :30 after this slot's; if this slot ran past it, the next starts now.
        slot="$(next_boundary "$slot")"
        if (( $(now) >= slot )); then
            echo "===== the slot ran past $(israel "$slot" '%H:%M'): the next starts now" >>"$LOG"
            slot="$(now)"
        fi
    done
    if ((STOP != 0)); then
        echo "===== stopped by request $(israel "$(now)" '%F %T %Z')" >>"$LOG"
    fi
}

latest_log() { ls -1 "$MEASURE_DIR"/*.log 2>/dev/null | sort | tail -n 1; }

totals() {
    local log="${1:-$(latest_log)}"
    if [[ -z "$log" || ! -f "$log" ]]; then
        echo "no log found in $MEASURE_DIR" >&2
        exit 1
    fi
    local script
    script="$(cat <<'PY'
import ast, json, re, sys
slots = runs_ok = runs_failed = rows = stored = 0
apify_usd = 0.0
apify_unknown = 0
cl_runs = cl_failed = calls = attempted = 0
usd = 0.0
tokens, outcomes = {}, {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if line.startswith("===== slot "):
        slots += 1
    m = re.match(r"--- (run_once|classify_pending), exit (\d+)", line)
    if m and m.group(2) != "0":
        if m.group(1) == "run_once":
            runs_failed += 1
        else:
            cl_failed += 1
    if not line.startswith("{"):
        continue
    try:
        msg = json.loads(line)["msg"]
    except (ValueError, KeyError, TypeError):
        continue
    m = re.match(r"apify_run \S+: .*usageTotalUsd (\S+)$", msg)
    if m:
        if m.group(1) in ("None", "null"):
            apify_unknown += 1
        else:
            apify_usd += float(m.group(1))
    m = re.match(r"run done: (\d+) rows fetched, (\d+) posts stored", msg)
    if m:
        runs_ok += 1
        rows += int(m.group(1))
        stored += int(m.group(2))
    m = re.match(
        r"classification done: \d+ found, \d+ skipped, (\d+) attempted, outcomes (\{.*?\}), "
        r".*?, (\d+) calls, tokens (\{.*?\}), \$([0-9.]+) of",
        msg,
    )
    if m:
        cl_runs += 1
        attempted += int(m.group(1))
        calls += int(m.group(3))
        usd += float(m.group(5))
        for key, value in ast.literal_eval(m.group(2)).items():
            outcomes[key] = outcomes.get(key, 0) + value
        for key, value in ast.literal_eval(m.group(4)).items():
            tokens[key] = tokens.get(key, 0) + value
unknown = f" ({apify_unknown} runs gave no figure)" if apify_unknown else ""
print(f"slots run: {slots}")
print(f"collection: {runs_ok} runs done, {runs_failed} failed; "
      f"{rows} rows fetched, {stored} posts stored")
print(f"  Apify, as each run reported it (usageTotalUsd): ${apify_usd:.4f}{unknown}")
print(f"classification: {cl_runs} runs done, {cl_failed} failed; {attempted} posts attempted, "
      f"outcomes {dict(sorted(outcomes.items()))}")
print(f"  {calls} model calls; tokens {tokens}; ${usd:.6f}")
print(f"together: ${apify_usd + usd:.4f} (then compare with both bills: Apify's and OpenAI's)")
PY
)"
    echo "totals of $log"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "$script" <"$log"
    else
        $COMPOSE run --rm -T jobs python -c "$script" <"$log"
    fi
}

case "${1:-}" in
    start)
        check_zone
        if pid="$(running_pid)"; then
            echo "already running (pid $pid)"
            exit 1
        fi
        mkdir -p "$MEASURE_DIR"
        nohup bash "$0" run >>"$MEASURE_DIR/measure_day.nohup.out" 2>&1 &
        sleep 2
        if pid="$(running_pid)"; then
            echo "started (pid $pid); the first slot at $(israel "$(next_boundary "$(now)")" '%H:%M') Israel time"
            echo "log: $(latest_log)"
        else
            echo "did not start; see $MEASURE_DIR/measure_day.nohup.out"
            exit 1
        fi
        ;;
    run) run_day ;;
    status)
        if pid="$(running_pid)"; then
            echo "running (pid $pid); log: $(latest_log)"
            grep -E '^(=====|--- )' "$(latest_log)" | tail -n 3
        else
            echo "not running"
        fi
        ;;
    log) tail -n "${2:-40}" "$(latest_log)" ;;
    stop)
        if pid="$(running_pid)"; then
            kill "$pid"
            echo "stop requested (pid $pid): the command running now finishes, then it stops"
            echo "check with: bash measure_day.sh status"
        else
            echo "not running"
        fi
        ;;
    totals) totals "${2:-}" ;;
    *)
        sed -n '2,8p' "$0"
        exit 1
        ;;
esac
