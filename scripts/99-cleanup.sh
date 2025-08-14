#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

# Delete leftover template if present
TEMPLATE_ID="$(load template.id)"
if [[ -n "$TEMPLATE_ID" ]]; then
  log "Deleting template $TEMPLATE_ID ..."
  awsj fis delete-experiment-template --id "$TEMPLATE_ID" >/dev/null || true
  rm -f "$TEMPLATE_FILE"
  ok "Template deleted"
else
  log "No template to delete"
fi

# Optionally delete role
ROLE_ARN="$(load role.arn)"
if [[ "${DELETE_ROLE_ON_DOWN:-false}" == "true" && -n "$ROLE_ARN" ]]; then
  ROLE_NAME="${FIS_ROLE_NAME:-FIS-SpotMinimalRole}"
  log "Deleting role $ROLE_NAME ..."
  # Remove inline policy if exists
  awsiam delete-role-policy --role-name "$ROLE_NAME" --policy-name "FISSpotInterruptionsMinimal" >/dev/null 2>&1 || true
  awsiam delete-role --role-name "$ROLE_NAME" >/dev/null 2>&1 || true
  rm -f "$ROLE_FILE"
  ok "Role deleted"
else
  log "Role retained (set DELETE_ROLE_ON_DOWN=true to remove)"
fi
