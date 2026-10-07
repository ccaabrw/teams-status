#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=teams-graph-common.sh
source "$SCRIPT_DIR/teams-graph-common.sh"

usage() {
    cat <<EOF
Usage: ${0##*/} --status STATUS [--duration HH:MM:SS] [--what-if]
       ${0##*/} --reset [--what-if]

Statuses: Available, Busy, DoNotDisturb, BeRightBack, Away, Offline
EOF
}

status=''
duration='01:00:00'
duration_supplied=false
reset=false
what_if=false

while (($#)); do
    case "$1" in
        --status)
            (($# >= 2)) || { printf 'Missing value for --status.\n' >&2; exit 2; }
            status=$2
            shift 2
            ;;
        --duration)
            (($# >= 2)) || { printf 'Missing value for --duration.\n' >&2; exit 2; }
            duration=$2
            duration_supplied=true
            shift 2
            ;;
        --reset)
            reset=true
            shift
            ;;
        --what-if)
            what_if=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ $reset == true ]]; then
    if [[ -n $status || $duration_supplied == true ]]; then
        printf '--reset cannot be combined with --status or --duration.\n' >&2
        exit 2
    fi
    operation=clearUserPreferredPresence
    action='Reset Teams presence'
    body='{}'
else
    if [[ -z $status ]]; then
        printf 'Specify --status STATUS or --reset.\n' >&2
        usage >&2
        exit 2
    fi

    case "${status,,}" in
        available) availability=Available; activity=Available ;;
        busy) availability=Busy; activity=Busy ;;
        donotdisturb) availability=DoNotDisturb; activity=DoNotDisturb ;;
        berightback) availability=BeRightBack; activity=BeRightBack ;;
        away) availability=Away; activity=Away ;;
        offline) availability=Offline; activity=OffWork ;;
        *)
            printf 'Unsupported status: %s\n' "$status" >&2
            exit 2
            ;;
    esac

    if [[ ! $duration =~ ^([0-9]+):([0-5][0-9]):([0-5][0-9])$ ]]; then
        printf 'Duration must use hours:minutes:seconds, for example 02:00:00.\n' >&2
        exit 2
    fi
    hours=${BASH_REMATCH[1]}
    minutes=${BASH_REMATCH[2]}
    seconds=${BASH_REMATCH[3]}
    if [[ ! $hours =~ [1-9] && $minutes == 00 && $seconds == 00 ]]; then
        printf 'Duration must be greater than zero.\n' >&2
        exit 2
    fi
    while [[ ${#hours} -gt 1 && ${hours:0:1} == 0 ]]; do hours=${hours:1}; done
    minutes=$((10#$minutes))
    seconds=$((10#$seconds))
    iso_duration="PT${hours}H${minutes}M${seconds}S"

    operation=setUserPreferredPresence
    action="Set Teams presence to $availability for $duration"
    body="$(jq -cn \
        --arg availability "$availability" \
        --arg activity "$activity" \
        --arg duration "$iso_duration" \
        '{availability:$availability,activity:$activity,expirationDuration:$duration}')"
fi

if [[ $what_if == true ]]; then
    printf '%s\n' "$action"
    exit 0
fi

teams_graph_init
trap 'rm -rf -- "$TEAMS_STATUS_TMPDIR"' EXIT
trap 'exit 1' HUP INT TERM

teams_graph_auth Presence.ReadWrite
body_file="$TEAMS_STATUS_TMPDIR/body"
printf '%s\n' "$body" >"$body_file"
teams_graph_api POST "/me/presence/$operation" "$body_file"
