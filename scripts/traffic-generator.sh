#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
RPS=10
DURATION=300
SERVICE="demo-app-stable"
NAMESPACE="demo-app"
ENDPOINTS=("/api/info" "/api/process" "/" "/health")

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -r, --rps <num>        Requests per second (default: 10)"
    echo "  -d, --duration <sec>   Duration in seconds (default: 300)"
    echo "  -s, --service <name>   Service name (default: demo-app-stable)"
    echo "  -n, --namespace <ns>   Namespace (default: demo-app)"
    echo "  --canary               Target canary service"
    echo "  --bluegreen            Target blue-green active service"
    echo "  --preview              Target blue-green preview service"
    echo "  --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Default: 10 RPS for 5 minutes"
    echo "  $0 -r 50 -d 600              # 50 RPS for 10 minutes"
    echo "  $0 --canary -r 20            # Target canary service"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rps)
            RPS=$2
            shift 2
            ;;
        -d|--duration)
            DURATION=$2
            shift 2
            ;;
        -s|--service)
            SERVICE=$2
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE=$2
            shift 2
            ;;
        --canary)
            SERVICE="demo-app-canary"
            shift
            ;;
        --bluegreen)
            SERVICE="demo-app-bg-active"
            shift
            ;;
        --preview)
            SERVICE="demo-app-bg-preview"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Traffic Generator                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Service:   ${SERVICE}.${NAMESPACE}"
echo -e "  RPS:       ${RPS}"
echo -e "  Duration:  ${DURATION}s"
echo ""

# Check if service exists
if ! kubectl get svc "$SERVICE" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Service ${SERVICE} not found in namespace ${NAMESPACE}${NC}"
    exit 1
fi

# Setup port-forward in background
echo -e "${YELLOW}🔗 Setting up port-forward...${NC}"
LOCAL_PORT=$(shuf -i 10000-60000 -n 1)
kubectl port-forward "svc/${SERVICE}" "${LOCAL_PORT}:80" -n "$NAMESPACE" &
PF_PID=$!

# Cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    kill $PF_PID 2>/dev/null || true
    echo -e "${GREEN}✅ Done${NC}"
}
trap cleanup EXIT

# Wait for port-forward
sleep 2

# Check connection
if ! curl -s "http://localhost:${LOCAL_PORT}/health" > /dev/null; then
    echo -e "${RED}Error: Cannot connect to service${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connected to service${NC}"
echo ""
echo -e "${YELLOW}🚀 Generating traffic...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
echo ""

# Calculate delay between requests
DELAY=$(echo "scale=4; 1 / $RPS" | bc)

# Counters
TOTAL=0
SUCCESS=0
ERRORS=0
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

# Generate traffic
while [ $(date +%s) -lt $END_TIME ]; do
    # Pick random endpoint
    ENDPOINT=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}

    # Make request
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${LOCAL_PORT}${ENDPOINT}" 2>/dev/null || echo "000")

    TOTAL=$((TOTAL + 1))

    if [ "$HTTP_CODE" == "200" ]; then
        SUCCESS=$((SUCCESS + 1))
        echo -ne "\r${GREEN}✓${NC} Total: $TOTAL | Success: $SUCCESS | Errors: $ERRORS | Rate: $(echo "scale=2; $SUCCESS * 100 / $TOTAL" | bc)%    "
    else
        ERRORS=$((ERRORS + 1))
        echo -ne "\r${RED}✗${NC} Total: $TOTAL | Success: $SUCCESS | Errors: $ERRORS | Rate: $(echo "scale=2; $SUCCESS * 100 / $TOTAL" | bc)%    "
    fi

    sleep "$DELAY"
done

echo ""
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Summary                                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total Requests:  $TOTAL"
echo -e "  Successful:      ${GREEN}$SUCCESS${NC}"
echo -e "  Errors:          ${RED}$ERRORS${NC}"
echo -e "  Success Rate:    $(echo "scale=2; $SUCCESS * 100 / $TOTAL" | bc)%"
echo -e "  Duration:        ${DURATION}s"
echo -e "  Actual RPS:      $(echo "scale=2; $TOTAL / $DURATION" | bc)"
echo ""
