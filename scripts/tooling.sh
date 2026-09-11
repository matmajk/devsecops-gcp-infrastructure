#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TOOLING_DIR="${TOOLING_DIR:-${REPO_ROOT}/local/tooling}"
COMPOSE_FILE="${TOOLING_COMPOSE_FILE:-${TOOLING_DIR}/compose.yaml}"
ENV_FILE="${TOOLING_ENV_FILE:-${TOOLING_DIR}/.env}"

KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-devsecops-local}"

TOOLING_ALLOW_CONCURRENT="${TOOLING_ALLOW_CONCURRENT:-0}"
TOOLING_RETRY_INTERVAL="${TOOLING_RETRY_INTERVAL:-5}"

SONARQUBE_READY_TIMEOUT="${SONARQUBE_READY_TIMEOUT:-180}"
JCR_READY_TIMEOUT="${JCR_READY_TIMEOUT:-600}"

PROFILE=""
READY_URL=""
READY_TIMEOUT=""
SERVICES=()


log() {
    printf '==> %s\n' "$*"
}


info() {
    printf '    %s\n' "$*"
}


warn() {
    printf 'WARNING: %s\n' "$*" >&2
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


on_error() {
    local exit_code=$?
    local line_number="${BASH_LINENO[0]:-unknown}"
    local command="${BASH_COMMAND:-unknown}"

    printf \
        'ERROR: Command failed with exit code %s at line %s: %s\n' \
        "${exit_code}" \
        "${line_number}" \
        "${command}" \
        >&2

    exit "${exit_code}"
}


trap on_error ERR


require_command() {
    local command="$1"

    command -v "${command}" >/dev/null 2>&1 \
        || die "Required command '${command}' was not found."
}


require_file() {
    local file="$1"

    [[ -f "${file}" ]] \
        || die "Required file does not exist: ${file}"
}


compose() {
    docker compose \
        --project-directory "${TOOLING_DIR}" \
        --env-file "${ENV_FILE}" \
        -f "${COMPOSE_FILE}" \
        "$@"
}


set_profile_context() {
    local profile="$1"

    case "${profile}" in
        sonarqube)
            PROFILE="sonarqube"
            SERVICES=(
                sonarqube
                sonarqube-db
            )
            READY_URL="http://localhost:9000/api/system/status"
            READY_TIMEOUT="${SONARQUBE_READY_TIMEOUT}"
            ;;
        jcr)
            PROFILE="jcr"
            SERVICES=(
                jcr
                jcr-db
            )
            READY_URL="http://localhost:8082/router/api/v1/system/readiness"
            READY_TIMEOUT="${JCR_READY_TIMEOUT}"
            ;;
        *)
            die "Unsupported tooling profile '${profile}'. Supported profiles: sonarqube, jcr."
            ;;
    esac
}


validate_environment() {
    require_command docker
    require_file "${COMPOSE_FILE}"
    require_file "${ENV_FILE}"

    docker compose version >/dev/null 2>&1 \
        || die "Docker Compose is not available."

    docker info >/dev/null 2>&1 \
        || die "Docker daemon is not available."
}


profile_is_running() {
    local profile="$1"

    compose \
        --profile "${profile}" \
        ps \
        --status running \
        --services \
        2>/dev/null \
        | grep -q .
}


kind_is_running() {
    docker ps \
        --filter "label=io.x-k8s.kind.cluster=${KIND_CLUSTER_NAME}" \
        --format '{{.ID}}' \
        | grep -q .
}


other_profile() {
    case "${PROFILE}" in
        sonarqube)
            printf '%s\n' "jcr"
            ;;
        jcr)
            printf '%s\n' "sonarqube"
            ;;
    esac
}


validate_resource_capacity() {
    local conflicting_profile

    if [[ "${TOOLING_ALLOW_CONCURRENT}" == "1" ]]; then
        warn "Concurrent resource checks are disabled."
        return 0
    fi

    if kind_is_running; then
        die "Kind cluster '${KIND_CLUSTER_NAME}' is running. Run 'make down' before starting '${PROFILE}', or explicitly use TOOLING_ALLOW_CONCURRENT=1."
    fi

    conflicting_profile="$(other_profile)"

    if profile_is_running "${conflicting_profile}"; then
        die "Tooling profile '${conflicting_profile}' is already running. Stop it before starting '${PROFILE}', or explicitly use TOOLING_ALLOW_CONCURRENT=1."
    fi
}


profile_health_check() {
    local response=""

    case "${PROFILE}" in
        sonarqube)
            if response="$(
                curl \
                    --fail \
                    --silent \
                    --show-error \
                    --max-time 5 \
                    "${READY_URL}" \
                    2>/dev/null
            )"; then
                grep -Eq \
                    '"status"[[:space:]]*:[[:space:]]*"UP"' \
                    <<< "${response}"
            else
                return 1
            fi
            ;;
        jcr)
            curl \
                --fail \
                --silent \
                --show-error \
                --max-time 5 \
                "${READY_URL}" \
                >/dev/null 2>&1
            ;;
    esac
}


show_profile_diagnostics() {
    warn "Tooling diagnostics for profile '${PROFILE}':"

    compose \
        --profile "${PROFILE}" \
        ps \
        -a \
        "${SERVICES[@]}" \
        >&2 || true

    compose \
        --profile "${PROFILE}" \
        logs \
        --tail=80 \
        "${SERVICES[@]}" \
        >&2 || true
}


wait_for_profile() {
    local start_time
    local current_time
    local elapsed_time

    require_command curl

    if ! profile_is_running "${PROFILE}"; then
        die "Tooling profile '${PROFILE}' is not running."
    fi

    start_time="$(date +%s)"

    log "Waiting for tooling profile '${PROFILE}'"

    while true; do
        if profile_health_check; then
            info "Tooling profile '${PROFILE}' is ready."
            return 0
        fi

        current_time="$(date +%s)"
        elapsed_time=$((current_time - start_time))

        if (( elapsed_time >= READY_TIMEOUT )); then
            show_profile_diagnostics
            die "Tooling profile '${PROFILE}' did not become ready within ${READY_TIMEOUT}s."
        fi

        info "Profile '${PROFILE}' is not ready yet. Retrying in ${TOOLING_RETRY_INTERVAL}s..."
        sleep "${TOOLING_RETRY_INTERVAL}"
    done
}


up_profile() {
    validate_resource_capacity

    log "Starting tooling profile '${PROFILE}'"

    compose \
        --profile "${PROFILE}" \
        up \
        -d

    wait_for_profile
}


down_profile() {
    log "Stopping tooling profile '${PROFILE}'"

    compose \
        --profile "${PROFILE}" \
        rm \
        --stop \
        --force \
        "${SERVICES[@]}"

    info "Tooling profile '${PROFILE}' stopped."
}


status_profile() {
    log "Tooling profile '${PROFILE}' status"

    compose \
        --profile "${PROFILE}" \
        ps \
        -a \
        "${SERVICES[@]}"
}


status_all() {
    log "Local tooling status"

    compose \
        --profile sonarqube \
        --profile jcr \
        ps \
        -a
}


down_all() {
    set_profile_context "sonarqube"
    down_profile

    set_profile_context "jcr"
    down_profile
}


logs_profile() {
    compose \
        --profile "${PROFILE}" \
        logs \
        --follow \
        "${SERVICES[@]}"
}


usage() {
    cat <<'EOF'
Usage:
  tooling.sh up <profile>
  tooling.sh down <profile>
  tooling.sh status [profile]
  tooling.sh wait <profile>
  tooling.sh logs <profile>
  tooling.sh down-all
  tooling.sh help

Profiles:
  sonarqube
  jcr

Examples:
  tooling.sh up sonarqube
  tooling.sh down sonarqube
  tooling.sh up jcr
  tooling.sh status jcr
  tooling.sh status
  tooling.sh wait jcr
  tooling.sh down-all

Environment variables:
  TOOLING_ALLOW_CONCURRENT
  TOOLING_RETRY_INTERVAL
  SONARQUBE_READY_TIMEOUT
  JCR_READY_TIMEOUT
  TOOLING_DIR
  TOOLING_COMPOSE_FILE
  TOOLING_ENV_FILE
  KIND_CLUSTER_NAME
EOF
}


main() {
    local command="${1:-help}"
    local profile="${2:-}"

    validate_environment

    case "${command}" in
        up|down|wait|logs)
            [[ -n "${profile}" ]] \
                || die "Profile is required for command '${command}'."

            set_profile_context "${profile}"
            ;;
        status)
            if [[ -n "${profile}" ]]; then
                set_profile_context "${profile}"
            fi
            ;;
        down-all|help|-h|--help)
            ;;
        *)
            usage
            die "Unknown command '${command}'."
            ;;
    esac

    case "${command}" in
        up)
            up_profile
            ;;
        down)
            down_profile
            ;;
        status)
            if [[ -n "${profile}" ]]; then
                status_profile
            else
                status_all
            fi
            ;;
        wait)
            wait_for_profile
            ;;
        logs)
            logs_profile
            ;;
        down-all)
            down_all
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            exit 1
            ;;
    esac
}


main "$@"