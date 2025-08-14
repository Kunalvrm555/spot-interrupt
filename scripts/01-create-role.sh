#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

ROLE_NAME="${FIS_ROLE_NAME:-FIS-SpotMinimalRole}"

# Reuse if exists
if ROLE_ARN="$(awsiam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null)"; then
  ok "Using existing role: $ROLE_ARN"
  save "role.arn" "$ROLE_ARN"
  exit 0
fi

log "Creating minimal FIS experiment role: $ROLE_NAME"

# Build JSON with here-doc via command substitution (Bash 3.2 friendly)
TRUST="$(cat <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "fis.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
JSON
)"

ROLE_ARN="$(awsiam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST" \
  --query 'Role.Arn' --output text)"
ok "Role created: $ROLE_ARN"

POLICY="$(cat <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowSpotInterruptions",
    "Effect": "Allow",
    "Action": [
      "ec2:SendSpotInstanceInterruptions",
      "ec2:DescribeInstances"
    ],
    "Resource": "*"
  }]
}
JSON
)"

awsiam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "FISSpotInterruptionsMinimal" \
  --policy-document "$POLICY" >/dev/null
ok "Attached minimal inline policy"

# Eventual consistency: wait until the role is visible
retry 10 2 -- awsiam get-role --role-name "$ROLE_NAME" >/dev/null || die "Role not visible after create"
ROLE_ARN="$(awsiam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)"
save "role.arn" "$ROLE_ARN"
ok "Saved role ARN to .state/role.arn"
