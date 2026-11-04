#!/usr/bin/env bash
# =============================================================================
# qem_export.sh - export tasks from one Replicate server into tasks/
#
# Purpose : the export step of a routine change. Called by export-from-dev.yml.
# Needs   : TASKS  ALL (every task on the server), or task names separated by
#                  commas or new lines
#           QEM_HOST, QEM_SERVER and the login variables (see qem_lib.sh)
# Output  : one tasks/<name>.json per task, without endpoints and with sorted
#           keys, so an unchanged task always produces the same text
# Notes   : it commits nothing; the workflow decides what to commit.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"
: "${TASKS:?Set TASKS to ALL or a list of task names}"
qem_login

NAMES=".qem_names.tmp"
if [ "$(printf '%s' "$TASKS" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')" = "ALL" ]; then
  curl -sS -f --header "EnterpriseManager.APISessionID: ${SESSION}" \
    "${BASE}/servers/${QEM_SERVER}/tasks" > .qem_tasklist.tmp
  jqx -r '.taskList[].name' .qem_tasklist.tmp > "$NAMES"
  rm -f .qem_tasklist.tmp
else
  printf '%s\n' "$TASKS" | tr ',' '\n' | tr -d '\r' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' > "$NAMES" || true
fi

if [ ! -s "$NAMES" ]; then
  echo "No task names to export." >&2
  rm -f "$NAMES"
  exit 1
fi

while IFS= read -r task; do
  [ -n "$task" ] || continue
  qem_export_task "$task"
done < "$NAMES"
rm -f "$NAMES"
