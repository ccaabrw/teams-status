#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=teams-graph-common.sh
source "$SCRIPT_DIR/teams-graph-common.sh"

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    printf 'Usage: %s\n' "${0##*/}"
    exit 0
fi
if (($#)); then
    printf 'This script does not accept arguments. Use --help for usage.\n' >&2
    exit 2
fi

teams_graph_init
trap 'rm -rf -- "$TEAMS_STATUS_TMPDIR"' EXIT
trap 'exit 1' HUP INT TERM

teams_graph_auth Presence.Read
teams_graph_api GET /me/presence
