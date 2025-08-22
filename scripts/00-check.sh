#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

log "Checking prerequisites..."
need aws
need jq
aws --profile awsmo-cust sts get-caller-identity >/dev/null || die "AWS CLI not authenticated"
ok "AWS CLI + jq OK; region=$REGION"
