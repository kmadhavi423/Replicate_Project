#!/usr/bin/env bash
# =============================================================================
# qem_import.sh - import task files into one Replicate server through QEM
#
# Purpose : the import step of a promotion. Called by promote.yml.
# Needs   : CHANGED_FILES  the task files to import, one path per line
#           STOP_TASKS     true (default) stops each existing task first
#           QEM_HOST, QEM_SERVER and the login variables (see qem_lib.sh)
# Steps   : 1. log in to QEM
#           2. stop each task that already exists on the server
#           3. import each file
#           4. print a count, and exit with an error if any task failed
# Notes   : one failed task does not block the others. Imported tasks stay
#           stopped; starting them is left to you.
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"

STOP_TASKS="${STOP_TASKS:-true}"
EXISTING=".qem_existing.tmp"

if [ -z "${CHANGED_FILES//[[:space:]]/}" ]; then
  echo "No changed task files; nothing to import."
  exit 0
fi

qem_login

if [ "$STOP_TASKS" = "true" ]; then
  qem_list_task_names > "$EXISTING"
fi

ok=0
failed=()
while IFS= read -r f; do
  f="${f%$'\r'}"
  [ -n "$f" ] || continue
  task=$(basename "$f" .json)
  if [ "$STOP_TASKS" = "true" ]; then
    if grep -Fxq -- "$task" "$EXISTING"; then
      if ! qem_stop_task "$task"; then
        echo "Skipping the import of ${task}, because it could not be stopped." >&2
        failed+=("$f")
        continue
      fi
    else
      echo "${task} does not exist on ${QEM_SERVER} yet; nothing to stop"
    fi
  fi
  if qem_import_file "$f"; then
    ok=$((ok + 1))
  else
    failed+=("$f")
  fi
done <<< "$CHANGED_FILES"
rm -f "$EXISTING"

echo "Imported: ${ok}   Failed: ${#failed[@]}"
if [ "$STOP_TASKS" = "true" ] && [ "$ok" -gt 0 ]; then
  echo "Imported tasks are stopped. Start them yourself when you are ready."
fi
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'Not imported: %s\n' "${failed[@]}" >&2
  exit 1
fi
