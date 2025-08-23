#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

TEMPLATE_ID="$(load template.id)"
[[ -n "$TEMPLATE_ID" ]] || die "Template ID missing; run 02-create-template.sh"

log "Starting experiment from template $TEMPLATE_ID ..."
START_TIME=$(start_timer)
EJSON="$(awsj fis start-experiment --experiment-template-id "$TEMPLATE_ID")"
EXP_ID="$(echo "$EJSON" | jq -r '.experiment.id')"
STATE="$(echo "$EJSON" | jq -r '.experiment.state.status')"
START="$(echo "$EJSON" | jq -r '.experiment.startTime')"
ok "Experiment $EXP_ID started (state: $STATE at $START)"

log "Polling until experiment completes/failed/stopped..."
while true; do
  sleep 10
  P="$(awsj fis get-experiment --id "$EXP_ID")" || die "get-experiment failed"
  S="$(echo "$P" | jq -r '.experiment.state.status')"
  R="$(echo "$P" | jq -r '.experiment.state.reason // ""')"
  echo "  - $S ${R:+($R)}"
  case "$S" in
    completed|failed|stopped) break;;
  esac
done

if [[ "$S" == "completed" ]]; then
  ok "SUCCESS: Experiment completed"
elif [[ "$S" == "failed" ]]; then
  warn "FAILED: Experiment failed ${R:+- $R}"
elif [[ "$S" == "stopped" ]]; then
  warn "STOPPED: Experiment stopped ${R:+- $R}"
else
  warn "Experiment finished with unexpected state: $S ${R:+($R)}"
fi

# Delete template immediately (leave role for re-use)
TEMPLATE_ID="$(load template.id)"
if [[ -n "$TEMPLATE_ID" ]]; then
  log "Deleting template $TEMPLATE_ID ..."
  awsj fis delete-experiment-template --id "$TEMPLATE_ID" >/dev/null || true
  rm -f "$TEMPLATE_FILE"
  ok "Template deleted"
fi
