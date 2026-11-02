#!/usr/bin/env bash
# Exports the task named in TASK from QEM_SERVER to tasks/<TASK>.json, without endpoints.
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"
: "${TASK:?Set TASK to the task name}"
qem_login
qem_export_task "$TASK"
