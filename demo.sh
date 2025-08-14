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
    "$ROOT_DIR/scripts/00-check.sh"
    "$ROOT_DIR/scripts/01-create-role.sh"
    ;;
  run)
    INSTANCE_ID="${1:-${INSTANCE_ID:-}}"
    if [[ -z "${INSTANCE_ID:-}" ]]; then
      die "Provide INSTANCE_ID via arg: ./demo.sh run i-abc... or set in .env"
    fi
    export INSTANCE_ID
    "$ROOT_DIR/scripts/02-create-template.sh"
    "$ROOT_DIR/scripts/03-start-experiment.sh"
    ;;
  down)
    "$ROOT_DIR/scripts/99-cleanup.sh"
    ;;
  *)
    cat <<USAGE
Usage:
  ./demo.sh up               # deps + create minimal role
  ./demo.sh run [INSTANCE]   # create one-off template + start experiment
  ./demo.sh down             # delete template (+ optional role)
USAGE
    ;;
esac
