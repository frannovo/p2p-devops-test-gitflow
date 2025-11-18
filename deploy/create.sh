#!/usr/bin/env bash
# =============================================================================
# ArgoCD + Kind Local Cluster Setup Script
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- Colors for better output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; } >&2

# --- Paths (resolved relative to script location) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_DEPLOYMENTS_PATH="$SCRIPT_DIR/../argocd-deployments"
ARGOCD_ROOT_APP_PATH="$ARGOCD_DEPLOYMENTS_PATH/applications.yaml"
ARGOCD_CHART_PATH="$SCRIPT_DIR/../charts/argocd"
CLUSTER_CONFIG="$SCRIPT_DIR/config.yml"

CLUSTER_NAME="${1:-p2p-devops}" # Allow override via argument: ./start.sh my-cluster
ARGOCD_NAMESPACE="argocd"
WAIT_TIMEOUT="600s"  # Total wait time for resources
SECRET_WAIT_TIMEOUT="120s"

# --- Helper functions ---
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Required command '$1' is not installed."
        exit 1
    fi
}

# Create Kind cluster if it doesn't exist
create_cluster() {
    local cluster_name="$1"
    local cluster_config="$2"

    if ! kind get clusters | grep -q "^${cluster_name}$"; then
        log "Cluster '$cluster_name' not found. Creating with config: $cluster_config"
        if [[ ! -f "$cluster_config" ]]; then
            error "Kind config file not found: $cluster_config"
            exit 1
        fi
        kind create cluster --name "$cluster_name" --config "$cluster_config" --wait 60s
    else
        log "Cluster '$cluster_name' already exists. Reusing it."
    fi

    # Ensure kubeconfig points to the right cluster
    kind export kubeconfig --name "$cluster_name"
}

wait_for_secret() {
    local total_timeout="$1"   # 5 minutes max
    local interval="5s"
    local elapsed=0

    log "Waiting for secret/argocd-initial-admin-secret to be created in namespace '$ARGOCD_NAMESPACE'..."

    # Parse total_timeout to seconds for calculation
    local total_seconds
    total_seconds=$(echo "$total_timeout" | sed 's/s$//')

    while true; do
        # Preferred: use kubectl wait with condition (works on recent versions)
        if kubectl wait --for=condition=type=kubernetes.io/tls \
            secret/argocd-initial-admin-secret \
            -n "$ARGOCD_NAMESPACE" \
            --timeout="$interval" >/dev/null 2>&1; then
            log "ArgoCD initial admin secret is ready!"
            return 0
        fi

        # Fallback: check if secret exists at all
        if kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            # Secret exists but might not have password yet — wait a bit more
            if kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" \
                -o jsonpath='{.data.password}' 2>/dev/null | grep -q '.'; then
                log "ArgoCD initial admin secret is ready (password populated)!"
                return 0
            fi
        fi

        elapsed=$((elapsed + $(echo "$interval" | sed 's/s$//')))
        local remaining=$((total_seconds - elapsed))

        if [ $remaining -le 0 ]; then
            error "Timeout reached: argocd-initial-admin-secret was not created within $total_timeout"
            error "Check ArgoCD controller logs with:"
            error "  kubectl logs -n argocd deploy/argocd-server"
            error "  kubectl logs -n argocd deploy/argocd-application-controller"
            exit 1
        fi

        warn "Still waiting for ArgoCD to generate admin secret... (~${remaining}s left)"
        sleep "$interval"
    done
}

get_admin_password() {
    kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" \
        -o jsonpath='{.data.password}' | base64 -d
}

# --- Main ---
main() {
    log "Starting local ArgoCD setup on Kind cluster: $CLUSTER_NAME"

    # Check prerequisites
    check_command kind
    check_command helm
    check_command kubectl
    check_command jq
    check_command base64

    create_cluster $CLUSTER_NAME $CLUSTER_CONFIG

    # Install/Upgrade ArgoCD via Helm
    log "Installing/ArgoCD via Helm in namespace '$ARGOCD_NAMESPACE'..."
    (
        cd "$ARGOCD_CHART_PATH" || {
            error "ArgoCD Helm chart directory not found: $ARGOCD_CHART_PATH"
            exit 1
        }

        helm dep update >/dev/null

        helm upgrade --install argocd . \
            --namespace "$ARGOCD_NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout "$WAIT_TIMEOUT" \
            --atomic
    )

    # Wait for initial admin secret
    wait_for_secret "$SECRET_WAIT_TIMEOUT"

    # Apply root Application
    if [[ ! -f "$ARGOCD_ROOT_APP_PATH" ]]; then
        error "Root Application manifest not found: $ARGOCD_ROOT_APP_PATH"
        exit 1
    fi

    log "Applying ArgoCD root Application..."
    kubectl apply -f "$ARGOCD_ROOT_APP_PATH" -n "$ARGOCD_NAMESPACE"

    # Retrieve and display admin password
    log "Retrieving ArgoCD admin password..."
    local password
    password=$(get_admin_password)
    echo
    echo "========================================"
    echo "  ArgoCD is ready!"
    echo "  Username: admin"
    echo "  Password: $password"
    echo "========================================"
    echo
    echo "Access the UI:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Then open: http://localhost:8080"
    echo
    echo
}

main "$@"