#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Port Forwarding                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Stopping all port-forwards...${NC}"
    pkill -f "kubectl port-forward" 2>/dev/null || true
    echo -e "${GREEN}✅ Done${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start port-forwards
echo -e "${YELLOW}Starting port-forwards...${NC}"
echo ""

# Argo Rollouts Dashboard
kubectl port-forward svc/argo-rollouts-dashboard 3100:3100 -n argo-rollouts &
echo -e "${GREEN}✅ Argo Rollouts Dashboard:${NC} http://localhost:3100"

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
echo -e "${GREEN}✅ Prometheus:${NC}             http://localhost:9090"

# Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &
echo -e "${GREEN}✅ Grafana:${NC}               http://localhost:3000 (admin/admin)"

# Alertmanager
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring &
echo -e "${GREEN}✅ Alertmanager:${NC}          http://localhost:9093"

# Demo App (stable)
kubectl port-forward svc/demo-app-stable 8080:80 -n demo-app 2>/dev/null &
echo -e "${GREEN}✅ Demo App (stable):${NC}     http://localhost:8080"

# Demo App (canary)
kubectl port-forward svc/demo-app-canary 8081:80 -n demo-app 2>/dev/null &
echo -e "${GREEN}✅ Demo App (canary):${NC}     http://localhost:8081"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  All services are now accessible. Press Ctrl+C to stop.     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Wait
wait
