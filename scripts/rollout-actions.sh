#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="demo-app"

usage() {
    echo "Usage: $0 <action> <rollout-name>"
    echo ""
    echo "Actions:"
    echo "  status      Show rollout status"
    echo "  watch       Watch rollout progress"
    echo "  promote     Promote rollout to next step"
    echo "  promote-full Fully promote rollout (skip remaining steps)"
    echo "  abort       Abort current rollout"
    echo "  retry       Retry aborted rollout"
    echo "  undo        Undo to previous version"
    echo "  pause       Pause rollout"
    echo "  resume      Resume paused rollout"
    echo "  restart     Restart rollout"
    echo ""
    echo "Rollout names:"
    echo "  canary              demo-app-canary"
    echo "  bluegreen           demo-app-bluegreen"
    echo "  bluegreen-manual    demo-app-bluegreen-manual"
    echo ""
    echo "Examples:"
    echo "  $0 status canary"
    echo "  $0 promote bluegreen-manual"
    echo "  $0 abort canary"
}

# Get rollout name from alias
get_rollout_name() {
    case $1 in
        canary)
            echo "demo-app-canary"
            ;;
        bluegreen)
            echo "demo-app-bluegreen"
            ;;
        bluegreen-manual)
            echo "demo-app-bluegreen-manual"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

ACTION=$1
ROLLOUT=$(get_rollout_name "$2")

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Rollout Actions                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Rollout:${NC} $ROLLOUT"
echo -e "${YELLOW}Action:${NC}  $ACTION"
echo ""

case $ACTION in
    status)
        kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE"
        ;;
    watch)
        kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE" -w
        ;;
    promote)
        echo -e "${YELLOW}Promoting rollout to next step...${NC}"
        kubectl argo rollouts promote "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${GREEN}✅ Rollout promoted${NC}"
        ;;
    promote-full)
        echo -e "${YELLOW}Fully promoting rollout...${NC}"
        kubectl argo rollouts promote "$ROLLOUT" -n "$NAMESPACE" --full
        echo -e "${GREEN}✅ Rollout fully promoted${NC}"
        ;;
    abort)
        echo -e "${YELLOW}Aborting rollout...${NC}"
        kubectl argo rollouts abort "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${RED}⛔ Rollout aborted${NC}"
        ;;
    retry)
        echo -e "${YELLOW}Retrying rollout...${NC}"
        kubectl argo rollouts retry rollout "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${GREEN}✅ Rollout retry initiated${NC}"
        ;;
    undo)
        echo -e "${YELLOW}Undoing to previous version...${NC}"
        kubectl argo rollouts undo "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${GREEN}✅ Rollout undone${NC}"
        ;;
    pause)
        echo -e "${YELLOW}Pausing rollout...${NC}"
        kubectl argo rollouts pause "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${YELLOW}⏸️  Rollout paused${NC}"
        ;;
    resume)
        echo -e "${YELLOW}Resuming rollout...${NC}"
        kubectl argo rollouts resume "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${GREEN}▶️  Rollout resumed${NC}"
        ;;
    restart)
        echo -e "${YELLOW}Restarting rollout...${NC}"
        kubectl argo rollouts restart "$ROLLOUT" -n "$NAMESPACE"
        echo -e "${GREEN}🔄 Rollout restarted${NC}"
        ;;
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        usage
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Current status:${NC}"
kubectl argo rollouts get rollout "$ROLLOUT" -n "$NAMESPACE" | head -20
