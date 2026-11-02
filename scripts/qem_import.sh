#!/usr/bin/env bash
# Imports only the task files listed in CHANGED_FILES (one path per line).
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"

if [ -z "${CHANGED_FILES//[[:space:]]/}" ]; then
  echo "No changed task files; nothing to import."
  exit 0
fi

qem_login

while IFS= read -r f; do
  f="${f%$'\r'}"
  [ -n "$f" ] || continue
  qem_import_file "$f"
done <<< "$CHANGED_FILES"
