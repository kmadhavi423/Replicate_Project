#!/usr/bin/env bash
# =============================================================================
# qem_baseline.sh - seed Git from PROD, and DEV from Git (run once at the start)
#
# Usage   : qem_baseline.sh export   read every task on QEM_SERVER (PROD) into
#                                    tasks/*.json, without endpoints
#           qem_baseline.sh import   import every tasks/*.json into QEM_SERVER (DEV)
# Needs   : QEM_HOST, QEM_SERVER and the login variables (see qem_lib.sh)
# Called  : by baseline.yml, first with "export" and then with "import".
# Notes   : it does not stop tasks, so stop any same-named DEV task before
#           the import.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"
qem_login

case "${1:-}" in
  export)
    mkdir -p tasks
    curl -sS -f --header "EnterpriseManager.APISessionID: ${SESSION}" \
      "${BASE}/servers/${QEM_SERVER}/tasks" > .qem_tasklist.tmp
    jqx -r '.taskList[].name' .qem_tasklist.tmp > .qem_tasknames.tmp
    rm -f .qem_tasklist.tmp
    while IFS= read -r task; do
      [ -n "$task" ] || continue
      qem_export_task "$task"
    done < .qem_tasknames.tmp
    rm -f .qem_tasknames.tmp
    ;;
  import)
    for f in tasks/*.json; do
      [ -e "$f" ] || { echo "No task files to import."; exit 0; }
      qem_import_file "$f"
    done
    ;;
  *)
    echo "usage: $0 export|import" >&2; exit 2 ;;
esac
