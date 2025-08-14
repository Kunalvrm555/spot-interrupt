#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
export AWS_PAGER=""

: "${INSTANCE_ID:?INSTANCE_ID not set}"
ROLE_ARN="$(load role.arn)"
[[ -n "$ROLE_ARN" ]] || die "FIS role not found. Run ./demo.sh up first."

# Validate instance is SPOT + running (and in this REGION)
DESC="$(awsj ec2 describe-instances --instance-ids "$INSTANCE_ID" 2>&1)" || die "Instance not found or wrong region: $DESC"
LIFECYCLE="$(echo "$DESC" | jq -r '.Reservations[0].Instances[0].InstanceLifecycle // ""')"
STATE="$(echo "$DESC" | jq -r '.Reservations[0].Instances[0].State.Name // ""')"
[[ "$LIFECYCLE" == "spot" ]] || die "Instance $INSTANCE_ID is not a Spot instance"
[[ "$STATE" == "running" ]] || die "Instance must be running (got: $STATE)"

# Check the action exists in this region
HAS_ACTION="$(aws fis list-actions --region "$REGION" \
  --query 'actions[?id==`aws:ec2:send-spot-instance-interruptions`].id' --output text 2>/dev/null || true)"
[[ "$HAS_ACTION" == "aws:ec2:send-spot-instance-interruptions" ]] || die "FIS action not available in region $REGION."

# Build instance ARN
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
INSTANCE_ARN="arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/${INSTANCE_ID}"

DURATION="${DURATION_ISO:-PT2M}"
log "Creating one-off FIS template targeting $INSTANCE_ID (ARN: $INSTANCE_ARN) with lead time $DURATION"

TF="$STATE_DIR/fis-template.json"
cat > "$TF" <<JSON
{
  "description": "Minimal: interrupt ${INSTANCE_ID}",
  "roleArn": "${ROLE_ARN}",
  "stopConditions": [ { "source": "none" } ],
  "targets": {
    "targetSpotInstances": {
      "resourceType": "aws:ec2:spot-instance",
      "resourceArns": ["${INSTANCE_ARN}"],
      "selectionMode": "ALL"
    }
  },
  "actions": {
    "interruptSpot": {
      "actionId": "aws:ec2:send-spot-instance-interruptions",
      "parameters": { "durationBeforeInterruption": "${DURATION}" },
      "targets": { "SpotInstances": "targetSpotInstances" }
    }
  },
  "tags": {
    "Project": "spot-interrupt-min",
    "ManagedBy": "scripts/02-create-template.sh"
  }
}
JSON

# Create template and surface any errors
set +e
CREATE_OUT="$(aws fis create-experiment-template --region "$REGION" --cli-input-json file://"$TF" 2>&1)"
STATUS=$?
set -e
if (( STATUS != 0 )); then
  echo "$CREATE_OUT" >&2
  die "Failed to create experiment template"
fi

TEMPLATE_ID="$(echo "$CREATE_OUT" | jq -r '.experimentTemplate.id')"
[[ -n "$TEMPLATE_ID" && "$TEMPLATE_ID" != "null" ]] || die "Template ID missing"
ok "Template: $TEMPLATE_ID"
save "template.id" "$TEMPLATE_ID"
