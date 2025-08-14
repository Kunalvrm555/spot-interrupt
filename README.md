# Spot Interrupt

Send a **real Spot interruption** to a specific Spot instance using **AWS FIS**.

## Requirements
- AWS CLI v2 (configured; `aws sts get-caller-identity` works)
- jq

## Quick start (single command)
```bash
# Edit .env first (INSTANCE_ID, REGION). Then:
./demo.sh up && ./demo.sh run && ./demo.sh down
```

## Typical workflow

```bash
# 1) Check deps + create minimal FIS role
./demo.sh up

# 2) Create a one-off template + start experiment (sends warning then interrupts)
./demo.sh run

# 3) Clean everything (template + optional role)
./demo.sh down
```

## Configuration

Copy and edit:

```bash
cp .env.example .env
```

Key variables:

* `REGION` – AWS region (e.g., `us-east-1`)
* `INSTANCE_ID` – **Spot** instance ID to interrupt (e.g., `i-0123456789abcdef0`)
* `DURATION_ISO` – Warning lead time (ISO 8601, `PT2M`..`PT15M`)
* `FIS_ROLE_NAME` – IAM role name used by FIS (default `FIS-SpotMinimalRole`)
* `DELETE_ROLE_ON_DOWN` – Set `true` to delete role during `down`

## What happens to the instance?

* FIS sends a **rebalance recommendation** immediately, then a **Spot interruption warning** with your `DURATION_ISO` lead time, and finally interrupts (terminate/stop depending on the instance's interruption behavior).

> Note: The instance must be **Spot** and **running**. On completion, you stop being billed for the instance; attached EBS may still incur cost if left around.

## Safety

* No CloudFormation. No EventBridge/Lambda. Minimal IAM.
* Creates a **single** experiment template, then deletes it.
