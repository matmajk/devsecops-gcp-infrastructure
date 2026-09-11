#!/usr/bin/env bash

set -Eeuo pipefail

DOCKER_BUILD_CACHE_KEEP_STORAGE="${DOCKER_BUILD_CACHE_KEEP_STORAGE:-5GB}"

log() {
    printf '[docker-cleanup] %s\n' "$*"
}

info() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

require_command() {
    local command_name="$1"

    command -v "${command_name}" >/dev/null 2>&1 \
        || die "Required command '${command_name}' was not found."
}

validate_docker() {
    require_command docker

    docker info >/dev/null 2>&1 \
        || die "Docker Engine is not reachable."
}

show_status() {
    log "Docker storage usage"

    docker system df

    if docker buildx version >/dev/null 2>&1; then
        printf '\n'
        log "BuildKit cache usage"
        docker buildx du
    fi
}

clean_build_cache() {
    log "Pruning unused Docker build cache"

    info "Build cache retained up to: ${DOCKER_BUILD_CACHE_KEEP_STORAGE}"

    docker buildx prune \
        --all \
        --force \
        --reserved-space "${DOCKER_BUILD_CACHE_KEEP_STORAGE}"

    info "Docker build cache cleanup completed."
}

clean_anonymous_volumes() {
    log "Pruning unused anonymous Docker volumes"

    warn "Named volumes are intentionally preserved."

    docker volume prune \
        --force

    info "Anonymous Docker volume cleanup completed."
}

clean() {
    log "Docker storage cleanup started"

    printf '\n'
    info "Storage usage before cleanup:"
    docker system df

    printf '\n'
    clean_build_cache

    printf '\n'
    clean_anonymous_volumes

    printf '\n'
    info "Storage usage after cleanup:"
    docker system df

    log "Docker storage cleanup completed"
}

usage() {
    cat <<'EOF'
Usage:
  docker-cleanup.sh <operation>

Operations:
  status    Show Docker disk usage and BuildKit cache usage
  cache     Prune unused build cache while retaining the configured cache size
  volumes   Prune unused anonymous volumes
  clean     Run cache and anonymous volume cleanup
  help      Show this help

Configuration:
  DOCKER_BUILD_CACHE_KEEP_STORAGE
      Amount of build cache to retain.

      Default:
        5GB

Safety:
  - named volumes are not removed
  - Docker images are not removed
  - containers are not removed
  - networks are not removed
  - docker system prune is not used
EOF
}

main() {
    local operation="${1:-help}"

    case "${operation}" in
        status)
            validate_docker
            show_status
            ;;
        cache)
            validate_docker
            clean_build_cache
            ;;
        volumes)
            validate_docker
            clean_anonymous_volumes
            ;;
        clean)
            validate_docker
            clean
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage
            die "Unsupported operation: ${operation}"
            ;;
    esac
}

main "$@"