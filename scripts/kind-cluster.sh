#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd
)"

readonly REPO_ROOT="$(
    cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1
    pwd
)"

readonly CLUSTER_NAME="${KIND_CLUSTER_NAME:-devsecops-local}"
readonly KIND_CONFIG="${KIND_CONFIG:-${REPO_ROOT}/local/kind/cluster.yaml}"
readonly KUBE_CONTEXT="kind-${CLUSTER_NAME}"
readonly READY_TIMEOUT="${KIND_READY_TIMEOUT:-180s}"


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
    local failed_command="${BASH_COMMAND:-unknown}"

    printf '\nERROR: Kind cluster operation failed.\n' >&2
    printf '       Exit code : %s\n' "${exit_code}" >&2
    printf '       Line      : %s\n' "${line_number}" >&2
    printf '       Command   : %s\n' "${failed_command}" >&2

    exit "${exit_code}"
}


trap on_error ERR


require_command() {
    local command_name="$1"

    command -v "${command_name}" >/dev/null 2>&1 \
        || die "Required command '${command_name}' was not found in PATH."
}


require_file() {
    local file="$1"

    [[ -f "${file}" ]] \
        || die "Required file does not exist: ${file}"
}


get_cluster_containers() {
    docker ps -a \
        --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}" \
        --format '{{.Names}}'
}


cluster_exists() {
    [[ -n "$(get_cluster_containers)" ]]
}


cluster_is_running() {
    local running
    local total

    total="$(get_cluster_containers | wc -l | tr -d ' ')"

    [[ "${total}" -gt 0 ]] || return 1

    running="$(
        docker ps \
            --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}" \
            --format '{{.Names}}' \
        | wc -l \
        | tr -d ' '
    )"

    [[ "${running}" -eq "${total}" ]]
}


validate_cluster_running() {
    cluster_exists \
        || die "Kind cluster '${CLUSTER_NAME}' does not exist. Run 'make bootstrap' first."

    cluster_is_running \
        || die "Kind cluster '${CLUSTER_NAME}' is stopped. Run 'make up' before waiting for readiness."
}


wait_for_api_server() {
    local timeout_seconds="${KIND_API_TIMEOUT:-60}"
    local retry_interval="${KIND_API_RETRY_INTERVAL:-2}"
    local deadline=$((SECONDS + timeout_seconds))

    log "Waiting for Kubernetes API server"

    while (( SECONDS < deadline )); do
        if MSYS_NO_PATHCONV=1 \
            kubectl \
                --context "${KUBE_CONTEXT}" \
                --request-timeout=5s \
                get --raw='/readyz' \
                >/dev/null 2>&1; then

            info "Kubernetes API server is reachable."
            return 0
        fi

        info "Kubernetes API server is not reachable yet. Retrying in ${retry_interval}s..."
        sleep "${retry_interval}"
    done

    die "Kubernetes API server did not become reachable within ${timeout_seconds}s."
}


wait_for_cluster() {
    log "Waiting for Kubernetes cluster '${CLUSTER_NAME}'"

    kubectl config use-context "${KUBE_CONTEXT}" >/dev/null

    validate_cluster_running
    refresh_kubeconfig
    wait_for_api_server
    validate_cluster_access

    kubectl wait \
        --context "${KUBE_CONTEXT}" \
        --for=condition=Ready \
        nodes \
        --all \
        --timeout="${READY_TIMEOUT}"

    info "All Kubernetes nodes are Ready."
}


create_cluster() {
    require_command docker
    require_command kind
    require_command kubectl
    require_file "${KIND_CONFIG}"

    if cluster_exists; then
        warn "Kind cluster '${CLUSTER_NAME}' already exists."

        if cluster_is_running; then
            info "Cluster '${CLUSTER_NAME}' is already running."
            refresh_kubeconfig
            wait_for_cluster
        else
            start_cluster
        fi

        return
    fi

    log "Creating Kind cluster '${CLUSTER_NAME}'"

    kind create cluster \
        --name "${CLUSTER_NAME}" \
        --config "${KIND_CONFIG}"

    wait_for_cluster
}


start_cluster() {
    require_command docker
    require_command kind
    require_command kubectl

    cluster_exists \
        || die "Kind cluster '${CLUSTER_NAME}' does not exist."

    if cluster_is_running; then
        info "Cluster '${CLUSTER_NAME}' is already running."
        wait_for_cluster
        return
    fi

    log "Starting Kind cluster '${CLUSTER_NAME}'"

    local -a containers=()
    mapfile -t containers < <(get_cluster_containers)

    docker start "${containers[@]}" >/dev/null

    wait_for_cluster
}


stop_cluster() {
    require_command docker

    cluster_exists \
        || die "Kind cluster '${CLUSTER_NAME}' does not exist."

    if ! cluster_is_running; then
        info "Cluster '${CLUSTER_NAME}' is already stopped."
        return
    fi

    log "Stopping Kind cluster '${CLUSTER_NAME}'"

    mapfile -t containers < <(get_cluster_containers)

    docker stop "${containers[@]}" >/dev/null

    info "Cluster stopped."
}


delete_cluster() {
    require_command kind
    require_command docker

    if ! cluster_exists; then
        info "Cluster '${CLUSTER_NAME}' does not exist."
        return
    fi

    log "Deleting Kind cluster '${CLUSTER_NAME}'"

    kind delete cluster \
        --name "${CLUSTER_NAME}"

    info "Cluster deleted."
}


show_status() {
    require_command docker

    log "Kind cluster '${CLUSTER_NAME}'"

    if ! cluster_exists; then
        info "Status: not created"
        return
    fi

    docker ps -a \
        --filter "label=io.x-k8s.kind.cluster=${CLUSTER_NAME}" \
        --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

    if cluster_is_running && command -v kubectl >/dev/null 2>&1; then
        echo
        kubectl get nodes \
            --context "${KUBE_CONTEXT}" \
            -o wide || true
    fi
}


refresh_kubeconfig() {
    log "Refreshing kubeconfig for Kind cluster '${CLUSTER_NAME}'"

    kind export kubeconfig \
        --name "${CLUSTER_NAME}" \
        >/dev/null

    info "Kubeconfig refreshed."
}


validate_cluster_access() {
    log "Validating Kubernetes cluster access"

    if ! kubectl auth can-i \
        list nodes \
        --all-namespaces \
        --context "${KUBE_CONTEXT}" \
        | grep -qx "yes"; then

        die "Current kubeconfig does not have permission to list cluster nodes for context '${KUBE_CONTEXT}'."
    fi

    info "Kubernetes cluster access validated."
}


usage() {
    cat <<EOF
Usage:
  $(basename "$0") <command>

Commands:
  create     Create the Kind cluster or start it if it already exists
  start      Start an existing stopped Kind cluster
  stop       Stop the Kind cluster without deleting it
  delete     Delete the Kind cluster
  status     Show cluster and node status
  wait       Wait until all Kubernetes nodes are Ready
EOF
}


main() {
    local command="${1:-}"

    case "${command}" in
        create)
            create_cluster
            ;;
        start)
            start_cluster
            ;;
        stop)
            stop_cluster
            ;;
        delete)
            delete_cluster
            ;;
        status)
            show_status
            ;;
        wait)
            require_command docker
            require_command kind
            require_command kubectl
            wait_for_cluster
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}


main "$@"