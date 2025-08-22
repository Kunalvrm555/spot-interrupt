#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR
source "$ROOT_DIR/scripts/common.sh"
load_env "$ROOT_DIR/.env"

cmd="${1:-}"
shift || true

case "${cmd}" in
  up)
    log "=== SETUP PHASE ==="
    "$ROOT_DIR/scripts/00-check.sh"
    "$ROOT_DIR/scripts/01-create-role.sh"
    ok "Setup completed successfully"
    ;;
  run)
    INSTANCE_ID="${1:-${INSTANCE_ID:-}}"
    if [[ -z "${INSTANCE_ID:-}" ]]; then
      die "Provide INSTANCE_ID via arg: ./demo.sh run i-abc... or set in .env"
    fi
    export INSTANCE_ID
    log "=== EXPERIMENT PHASE ==="
    REBALANCE_ONLY="${REBALANCE_ONLY:-false}"
    if [[ "$REBALANCE_ONLY" == "true" ]]; then
      log "Mode: REBALANCE RECOMMENDATION ONLY"
    else
      log "Mode: SPOT INTERRUPTION (duration: ${DURATION_ISO:-PT2M})"
    fi
    log "Target instance: $INSTANCE_ID"
    DEMO_START=$(start_timer)
    "$ROOT_DIR/scripts/02-create-template.sh"
    "$ROOT_DIR/scripts/03-start-experiment.sh"
    DEMO_ELAPSED=$(elapsed_time $DEMO_START)
    ok "Experiment phase completed in $DEMO_ELAPSED"
    ;;
  down)
    log "=== CLEANUP PHASE ==="
    "$ROOT_DIR/scripts/99-cleanup.sh"
    ok "Cleanup completed"
    ;;
  rebalance)
    INSTANCE_ID="${1:-${INSTANCE_ID:-}}"
    if [[ -z "${INSTANCE_ID:-}" ]]; then
      die "Provide INSTANCE_ID via arg: ./demo.sh rebalance i-abc... or set in .env"
    fi
    export INSTANCE_ID
    export REBALANCE_ONLY=true
    log "=== REBALANCE RECOMMENDATION PHASE ==="
    log "Target instance: $INSTANCE_ID"
    DEMO_START=$(start_timer)
    "$ROOT_DIR/scripts/02-create-template.sh"
    "$ROOT_DIR/scripts/03-start-experiment.sh"
    DEMO_ELAPSED=$(elapsed_time $DEMO_START)
    ok "Rebalance recommendation completed in $DEMO_ELAPSED"
    ;;
  *)
    cat <<USAGE
Usage:
  ./demo.sh up                    # deps + create minimal role
  ./demo.sh run [INSTANCE]        # create template + start interruption experiment
  ./demo.sh rebalance [INSTANCE]  # send only rebalance recommendation
  ./demo.sh down                  # delete template (+ optional role)

Environment variables:
  REBALANCE_ONLY=true             # set to send only rebalance recommendation
  DURATION_ISO=PT2M               # lead time before interruption (default: 2 minutes)
USAGE
    ;;
esac
