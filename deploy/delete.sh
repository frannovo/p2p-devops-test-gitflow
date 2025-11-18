#!/usr/bin/env bash
# =============================================================================
# Safe Kind Cluster Deletion Script
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; } >&2

# --- Config ---
CLUSTER_NAME="${1:-p2p-devops}"  # Allow override via argument: ./delete.sh my-cluster

# --- Helper: check if cluster exists ---
cluster_exists() {
    kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

# --- Main ---
main() {
    log "Deleting ${CLUSTER_NAME}"

    if ! command -v kind &>/dev/null; then
        error "kind is not installed or not in PATH"
        exit 1
    fi

    if ! cluster_exists; then
        warn "No cluster named '${CLUSTER_NAME}' found."
        log "Available clusters:"
        kind get clusters | sed 's/^/  - /'
        echo
        exit 0
    fi

    echo
    echo -e "${YELLOW}You are about to ${BOLD}PERMANENTLY DELETE${NC}${YELLOW} the following Kind cluster:${NC}"
    echo
    echo -e "     ${BOLD}${RED}${CLUSTER_NAME}${NC}"
    echo
    echo -e "${DIM}This will destroy all pods, volumes, networks, and data, ArgoCD, apps, etc.${NC}"
    echo

    echo -e "${YELLOW}To confirm deletion, type the cluster name exactly:${NC}"
    printf " ${BOLD}%s${NC} -> " "$CLUSTER_NAME"
    read -r typed_name
    echo

    if [[ "$typed_name" != "$CLUSTER_NAME" ]]; then
        error "Names do not match. Aborting."
        exit 1
    fi

    log "Deleting cluster '${CLUSTER_NAME}'..."
    if kind delete cluster --name "$CLUSTER_NAME"; then
        echo
        log "Cluster '${CLUSTER_NAME}' has been successfully deleted."
        echo
    else
        error "Failed to delete cluster '${CLUSTER_NAME}'"
        exit 1
    fi
}

main "$@"