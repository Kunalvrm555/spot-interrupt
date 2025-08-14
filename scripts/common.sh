#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "$*"; }
ok()  { echo -e "✓ $*"; }
warn(){ echo -e "⚠ $*" >&2; }
die() { echo -e "✗ $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

load_env() {
  local f="${1:-}"
  [[ -f "$f" ]] && set -a && source "$f" && set +a
  : "${REGION:?Set REGION in .env or environment}"
  export REGION
}

awsj() {
  aws --region "$REGION" --output json "$@"
}

awsiam() {
  aws iam "$@" # IAM is global: never pass --region
}

retry() { # retry <times> <sleep_seconds> -- <cmd ...>
  local n="$1" s="$2"
  shift 2
  [[ "${1:-}" == "--" ]] && shift   # drop optional separator
  local i=1 status=0
  while true; do
    "$@"; status=$?
    if (( status == 0 )); then return 0; fi
    if (( i >= n )); then return "$status"; fi
    sleep "$s"
    ((i++))
  done
}


STATE_DIR="${ROOT_DIR:-.}/.state"
mkdir -p "$STATE_DIR"
TEMPLATE_FILE="$STATE_DIR/template.id"
ROLE_FILE="$STATE_DIR/role.arn"

save() { echo -n "$2" > "$STATE_DIR/$1"; }
load() { [[ -f "$STATE_DIR/$1" ]] && cat "$STATE_DIR/$1" || true; }
