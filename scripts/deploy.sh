#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="${SCRIPT_DIR}/.."

usage() {
    echo "Usage: $0 <strategy> <version> [options]"
    echo ""
    echo "Strategies:"
    echo "  canary              Deploy using Canary strategy"
    echo "  bluegreen           Deploy using Blue-Green strategy"
    echo "  bluegreen-manual    Deploy using Blue-Green with manual promotion"
    echo ""
    echo "Versions:"
    echo "  v1                  Stable version (blue, 0% error rate)"
    echo "  v2                  New version (green, 0% error rate)"
    echo "  v3-bad              Bad version (red, 20% error rate)"
    echo "  v4-slow             Slow version (orange, high latency)"
    echo ""
    echo "Options:"
    echo "  --error-rate <rate> Set custom error rate (0.0 to 1.0)"
    echo "  --latency <ms>      Set custom latency in milliseconds"
    echo ""
    echo "Examples:"
    echo "  $0 canary v2                    # Deploy v2 with canary"
    echo "  $0 bluegreen v2                 # Deploy v2 with blue-green"
    echo "  $0 canary v3-bad                # Deploy bad version (will fail analysis)"
    echo "  $0 canary v2 --error-rate 0.05  # Deploy v2 with 5% error rate"
}

# Parse arguments
STRATEGY=""
VERSION=""
ERROR_RATE=""
LATENCY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        canary|bluegreen|bluegreen-manual)
            STRATEGY=$1
            shift
            ;;
        v1|v2|v3-bad|v4-slow)
            VERSION=$1
            shift
            ;;
        --error-rate)
            ERROR_RATE=$2
            shift 2
            ;;
        --latency)
            LATENCY=$2
            shift 2
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

if [ -z "$STRATEGY" ] || [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Strategy and version are required${NC}"
    usage
    exit 1
fi

# Set version-specific defaults
case $VERSION in
    v1)
        COLOR="blue"
        DEFAULT_ERROR_RATE="0.0"
        DEFAULT_LATENCY="50"
        ;;
    v2)
        COLOR="green"
        DEFAULT_ERROR_RATE="0.0"
        DEFAULT_LATENCY="50"
        ;;
    v3-bad)
        COLOR="red"
        DEFAULT_ERROR_RATE="0.20"
        DEFAULT_LATENCY="100"
        ;;
    v4-slow)
        COLOR="orange"
        DEFAULT_ERROR_RATE="0.02"
        DEFAULT_LATENCY="500"
        ;;
esac

# Use custom values if provided
ERROR_RATE=${ERROR_RATE:-$DEFAULT_ERROR_RATE}
LATENCY=${LATENCY:-$DEFAULT_LATENCY}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Deploying Demo App                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Strategy:${NC}    $STRATEGY"
echo -e "${YELLOW}Version:${NC}     $VERSION"
echo -e "${YELLOW}Color:${NC}       $COLOR"
echo -e "${YELLOW}Error Rate:${NC}  $ERROR_RATE"
echo -e "${YELLOW}Latency:${NC}     ${LATENCY}ms"
echo ""

# Select rollout file based on strategy
case $STRATEGY in
    canary)
        ROLLOUT_FILE="${PROJECT_DIR}/manifests/rollouts/canary-rollout.yaml"
        ROLLOUT_NAME="demo-app-canary"
        ;;
    bluegreen)
        ROLLOUT_FILE="${PROJECT_DIR}/manifests/rollouts/bluegreen-rollout.yaml"
        ROLLOUT_NAME="demo-app-bluegreen"
        ;;
    bluegreen-manual)
        ROLLOUT_FILE="${PROJECT_DIR}/manifests/rollouts/bluegreen-rollout-manual.yaml"
        ROLLOUT_NAME="demo-app-bluegreen-manual"
        ;;
esac

# Update the rollout with new version
echo -e "${YELLOW}📦 Updating rollout...${NC}"

# Create temporary file with updated values
TEMP_FILE=$(mktemp)
sed -e "s|image: demo-app:.*|image: demo-app:${VERSION}|g" \
    -e "s|value: \"v[0-9]*\"|value: \"${VERSION}\"|g" \
    -e "s|value: \"blue\"|value: \"${COLOR}\"|g" \
    -e "s|value: \"green\"|value: \"${COLOR}\"|g" \
    -e "s|value: \"red\"|value: \"${COLOR}\"|g" \
    -e "s|value: \"orange\"|value: \"${COLOR}\"|g" \
    -e "s|ERROR_RATE.*|ERROR_RATE\n            value: \"${ERROR_RATE}\"|g" \
    -e "s|LATENCY_MS.*|LATENCY_MS\n            value: \"${LATENCY}\"|g" \
    "$ROLLOUT_FILE" > "$TEMP_FILE"

# Apply the rollout
kubectl apply -f "$TEMP_FILE"
rm "$TEMP_FILE"

echo -e "${GREEN}✅ Rollout updated${NC}"
echo ""

# Watch the rollout
echo -e "${YELLOW}👀 Watching rollout progress...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop watching (rollout will continue)${NC}"
echo ""

kubectl argo rollouts get rollout "$ROLLOUT_NAME" -n demo-app -w || true

echo ""
echo -e "${GREEN}📊 View in Grafana:${NC}"
echo "   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo ""
echo -e "${GREEN}🎛️  Argo Rollouts Dashboard:${NC}"
echo "   kubectl argo rollouts dashboard -n argo-rollouts"
