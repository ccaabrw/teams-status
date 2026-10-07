#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=teams-graph-common.sh
source "$SCRIPT_DIR/teams-graph-common.sh"

TEAMS_CACHE_TOKEN=false
while (($#)); do
    case "$1" in
        --cache-token) TEAMS_CACHE_TOKEN=true; shift ;;
        --help|-h)
            printf 'Usage: %s [--cache-token]\n' "${0##*/}"
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s. Use --help for usage.\n' "$1" >&2
            exit 2
            ;;
    esac
done

teams_graph_init
trap 'rm -rf -- "$TEAMS_STATUS_TMPDIR"' EXIT
trap 'exit 1' HUP INT TERM

teams_graph_auth Presence.Read
teams_graph_api GET /me/presence
