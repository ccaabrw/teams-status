#!/usr/bin/env bash

TEAMS_GRAPH_CLIENT_ID='14d82eec-204b-4c2f-b7e8-296a70dab67e'
TEAMS_GRAPH_BASE_URL='https://graph.microsoft.com/v1.0'
TEAMS_LOGIN_BASE_URL='https://login.microsoftonline.com/organizations/oauth2/v2.0'

teams_graph_init() {
    local dependency
    for dependency in curl jq; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            printf 'Required command not found: %s\n' "$dependency" >&2
            return 1
        fi
    done

    TEAMS_STATUS_TMPDIR="$(mktemp -d)" || {
        printf 'Unable to create a temporary directory.\n' >&2
        return 1
    }
    TEAMS_RESPONSE_FILE="$TEAMS_STATUS_TMPDIR/response"
    TEAMS_ACCESS_TOKEN=''
}

teams_graph_http() {
    local method=$1
    local url=$2
    local data_file=${3:-}
    local -a curl_args=(--silent --show-error --output "$TEAMS_RESPONSE_FILE" --write-out '%{http_code}' --request "$method")

    if [[ -n $data_file ]]; then
        curl_args+=(--data-binary "@$data_file")
    fi

    TEAMS_HTTP_STATUS="$(curl "${curl_args[@]}" "$url")" || {
        printf 'Request to %s failed.\n' "$url" >&2
        return 1
    }
}

teams_graph_auth() {
    local scope=$1
    local form_file="$TEAMS_STATUS_TMPDIR/form"
    local device_code user_code verification_uri expires_in interval
    local token_error

    jq -nr \
        --arg client_id "$TEAMS_GRAPH_CLIENT_ID" \
        --arg scope "https://graph.microsoft.com/$scope" \
        '"client_id=\($client_id|@uri)&scope=\($scope|@uri)"' >"$form_file"

    teams_graph_http POST "$TEAMS_LOGIN_BASE_URL/devicecode" "$form_file" || return 1
    if [[ ! $TEAMS_HTTP_STATUS =~ ^2 ]]; then
        printf 'Device-code request failed (HTTP %s):\n' "$TEAMS_HTTP_STATUS" >&2
        cat "$TEAMS_RESPONSE_FILE" >&2
        return 1
    fi

    device_code="$(jq -r '.device_code // empty' "$TEAMS_RESPONSE_FILE")"
    user_code="$(jq -r '.user_code // empty' "$TEAMS_RESPONSE_FILE")"
    verification_uri="$(jq -r '.verification_uri // empty' "$TEAMS_RESPONSE_FILE")"
    expires_in="$(jq -r '.expires_in // empty' "$TEAMS_RESPONSE_FILE")"
    interval="$(jq -r '.interval // 5' "$TEAMS_RESPONSE_FILE")"
    if [[ -z $device_code || -z $user_code || -z $verification_uri || ! $expires_in =~ ^[0-9]+$ || ! $interval =~ ^[0-9]+$ ]]; then
        printf 'The device-code response was incomplete or invalid.\n' >&2
        return 1
    fi

    printf 'Sign in at %s and enter code %s\n' "$verification_uri" "$user_code" >&2
    jq -nr \
        --arg client_id "$TEAMS_GRAPH_CLIENT_ID" \
        --arg device_code "$device_code" \
        '"client_id=\($client_id|@uri)&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=\($device_code|@uri)"' >"$form_file"

    SECONDS=0
    while (( SECONDS < expires_in )); do
        sleep "$interval"
        teams_graph_http POST "$TEAMS_LOGIN_BASE_URL/token" "$form_file" || return 1
        if [[ $TEAMS_HTTP_STATUS =~ ^2 ]]; then
            TEAMS_ACCESS_TOKEN="$(jq -r '.access_token // empty' "$TEAMS_RESPONSE_FILE")"
            if [[ -n $TEAMS_ACCESS_TOKEN ]]; then
                return 0
            fi
        fi

        token_error="$(jq -r '.error // empty' "$TEAMS_RESPONSE_FILE")"
        case "$token_error" in
            authorization_pending) ;;
            slow_down) ((interval += 5)) ;;
            *)
                printf 'Sign-in failed'
                if [[ -n $token_error ]]; then
                    printf ' (%s)' "$token_error"
                fi
                printf ':\n' >&2
                cat "$TEAMS_RESPONSE_FILE" >&2
                return 1
                ;;
        esac
    done

    printf 'Device-code sign-in expired before it was completed.\n' >&2
    return 1
}

teams_graph_api() {
    local method=$1
    local uri=$2
    local body_file=${3:-}
    local header_file="$TEAMS_STATUS_TMPDIR/headers"

    printf 'Authorization: ******' "$TEAMS_ACCESS_TOKEN" >"$header_file"
    chmod 600 "$header_file"
    local -a curl_args=(--silent --show-error --output "$TEAMS_RESPONSE_FILE" --write-out '%{http_code}' --request "$method" --header "@$header_file")
    if [[ -n $body_file ]]; then
        curl_args+=(--header 'Content-Type: application/json' --data-binary "@$body_file")
    fi

    TEAMS_HTTP_STATUS="$(curl "${curl_args[@]}" "$TEAMS_GRAPH_BASE_URL$uri")" || {
        printf 'Microsoft Graph request failed.\n' >&2
        return 1
    }
    if [[ ! $TEAMS_HTTP_STATUS =~ ^2 ]]; then
        printf 'Microsoft Graph request failed (HTTP %s):\n' "$TEAMS_HTTP_STATUS" >&2
        cat "$TEAMS_RESPONSE_FILE" >&2
        return 1
    fi
    if [[ -s $TEAMS_RESPONSE_FILE ]]; then
        jq . "$TEAMS_RESPONSE_FILE"
    fi
}
