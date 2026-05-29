#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Argo Rollouts Lab - Setup Script (Helm)            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl found${NC}"

    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ helm not found. Please install helm first.${NC}"
        echo -e "${YELLOW}   brew install helm (macOS) or see https://helm.sh/docs/intro/install/${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ helm found ($(helm version --short))${NC}"

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster.${NC}"
        echo -e "${YELLOW}   Make sure you have a running cluster (minikube, kind, k3d, etc.)${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"

    echo ""
}

# Add Helm repositories
add_helm_repos() {
    echo -e "${YELLOW}📦 Adding Helm repositories...${NC}"

    helm repo add argo https://argoproj.github.io/argo-helm || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
    helm repo add grafana https://grafana.github.io/helm-charts || true
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true

    helm repo update

    echo -e "${GREEN}✅ Helm repositories added${NC}"
    echo ""
}

# Create namespaces
create_namespaces() {
    echo -e "${YELLOW}🏗️  Creating namespaces...${NC}"

    kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace demo-app --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    echo -e "${GREEN}✅ Namespaces created${NC}"
    echo ""
}

# Install Argo Rollouts via Helm
install_argo_rollouts() {
    echo -e "${YELLOW}🚀 Installing Argo Rollouts via Helm...${NC}"

    helm upgrade --install argo-rollouts argo/argo-rollouts \
        --namespace argo-rollouts \
        --set dashboard.enabled=true \
        --set dashboard.service.type=ClusterIP \
        --set controller.metrics.enabled=true \
        --set controller.metrics.serviceMonitor.enabled=true \
        --wait

    echo -e "${GREEN}✅ Argo Rollouts installed${NC}"
    echo ""
}

# Install Prometheus Stack via Helm
install_prometheus() {
    echo -e "${YELLOW}📊 Installing Prometheus Stack via Helm...${NC}"

    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
        --set grafana.enabled=true \
        --set grafana.adminPassword=admin \
        --set grafana.sidecar.dashboards.enabled=true \
        --set grafana.sidecar.dashboards.searchNamespace=ALL \
        --set alertmanager.enabled=true \
        --set nodeExporter.enabled=true \
        --set kubeStateMetrics.enabled=true \
        --wait --timeout 10m

    echo -e "${GREEN}✅ Prometheus Stack installed${NC}"
    echo ""
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    echo -e "${YELLOW}🌐 Installing NGINX Ingress Controller via Helm...${NC}"

    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.metrics.enabled=true \
        --set controller.metrics.serviceMonitor.enabled=true \
        --wait

    echo -e "${GREEN}✅ NGINX Ingress Controller installed${NC}"
    echo ""
}

# Install kubectl argo-rollouts plugin
install_kubectl_plugin() {
    echo -e "${YELLOW}🔌 Installing kubectl argo-rollouts plugin...${NC}"

    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    KUBECTL_ARGO_ROLLOUTS_VERSION="v1.6.4"
    PLUGIN_URL="https://github.com/argoproj/argo-rollouts/releases/download/${KUBECTL_ARGO_ROLLOUTS_VERSION}/kubectl-argo-rollouts-${OS}-${ARCH}"

    if [ -w "/usr/local/bin" ]; then
        curl -sLO ${PLUGIN_URL}
        chmod +x kubectl-argo-rollouts-${OS}-${ARCH}
        mv kubectl-argo-rollouts-${OS}-${ARCH} /usr/local/bin/kubectl-argo-rollouts
        echo -e "${GREEN}✅ kubectl plugin installed to /usr/local/bin${NC}"
    else
        mkdir -p ~/.local/bin
        curl -sLO ${PLUGIN_URL}
        chmod +x kubectl-argo-rollouts-${OS}-${ARCH}
        mv kubectl-argo-rollouts-${OS}-${ARCH} ~/.local/bin/kubectl-argo-rollouts
        echo -e "${GREEN}✅ kubectl plugin installed to ~/.local/bin${NC}"
        echo -e "${YELLOW}   Add ~/.local/bin to your PATH if not already done${NC}"
    fi
    echo ""
}

# Apply custom resources (Analysis Templates, etc.)
apply_custom_resources() {
    echo -e "${YELLOW}📝 Applying Analysis Templates and custom resources...${NC}"

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    # Apply Analysis Templates
    kubectl apply -f "${SCRIPT_DIR}/../manifests/analysis/" || true

    # Apply ServiceMonitor for demo-app
    kubectl apply -f "${SCRIPT_DIR}/../infrastructure/prometheus/servicemonitor.yaml" || true

    echo -e "${GREEN}✅ Custom resources applied${NC}"
    echo ""
}

# Create Grafana dashboard ConfigMap
create_grafana_dashboard() {
    echo -e "${YELLOW}📈 Creating Argo Rollouts Grafana Dashboard...${NC}"

    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    kubectl apply -f "${SCRIPT_DIR}/../infrastructure/grafana/dashboard-configmap.yaml" || true

    echo -e "${GREEN}✅ Grafana dashboard created${NC}"
    echo ""
}

# Print access information
print_access_info() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Setup Complete! 🎉                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}📍 Access Information:${NC}"
    echo ""
    echo -e "   ${YELLOW}Argo Rollouts Dashboard:${NC}"
    echo "   kubectl argo rollouts dashboard -n argo-rollouts"
    echo "   Or: kubectl port-forward svc/argo-rollouts-dashboard 3100:3100 -n argo-rollouts"
    echo "   Then open: http://localhost:3100"
    echo ""
    echo -e "   ${YELLOW}Prometheus:${NC}"
    echo "   kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
    echo "   Then open: http://localhost:9090"
    echo ""
    echo -e "   ${YELLOW}Grafana:${NC}"
    echo "   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
    echo "   Then open: http://localhost:3000 (admin/admin)"
    echo ""
    echo -e "   ${YELLOW}Alertmanager:${NC}"
    echo "   kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring"
    echo "   Then open: http://localhost:9093"
    echo ""
    echo -e "${GREEN}🚀 Quick Start:${NC}"
    echo ""
    echo "   # Deploy Canary Rollout"
    echo "   kubectl apply -f manifests/rollouts/canary-rollout.yaml"
    echo ""
    echo "   # Deploy Blue-Green Rollout"
    echo "   kubectl apply -f manifests/rollouts/bluegreen-rollout.yaml"
    echo ""
    echo "   # Watch rollout progress"
    echo "   kubectl argo rollouts get rollout demo-app-canary -n demo-app -w"
    echo ""
    echo -e "${GREEN}📚 See README.md for detailed usage instructions${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up Argo Rollouts Lab...${NC}"

    helm uninstall argo-rollouts -n argo-rollouts 2>/dev/null || true
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true

    kubectl delete namespace demo-app 2>/dev/null || true
    kubectl delete namespace argo-rollouts 2>/dev/null || true
    kubectl delete namespace monitoring 2>/dev/null || true
    kubectl delete namespace ingress-nginx 2>/dev/null || true

    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Main execution
main() {
    check_prerequisites
    add_helm_repos
    create_namespaces
    install_argo_rollouts
    install_prometheus
    install_nginx_ingress
    install_kubectl_plugin
    apply_custom_resources
    create_grafana_dashboard
    print_access_info
}

# Run with optional flags
case "${1:-}" in
    --cleanup)
        cleanup
        ;;
    --argo-only)
        check_prerequisites
        add_helm_repos
        create_namespaces
        install_argo_rollouts
        install_kubectl_plugin
        ;;
    --monitoring-only)
        check_prerequisites
        add_helm_repos
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        install_prometheus
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)              Full installation (Argo Rollouts + Prometheus + Grafana + NGINX)"
        echo "  --argo-only         Only install Argo Rollouts"
        echo "  --monitoring-only   Only install Prometheus/Grafana stack"
        echo "  --cleanup           Remove all installed components"
        echo "  --help, -h          Show this help message"
        ;;
    *)
        main
        ;;
esac
