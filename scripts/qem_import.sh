#!/usr/bin/env bash
# Imports only the task files listed in CHANGED_FILES (one path per line).
# Keeps going after a failure, then fails at the end and lists what did not import.
set -euo pipefail
source "$(dirname "$0")/qem_lib.sh"

if [ -z "${CHANGED_FILES//[[:space:]]/}" ]; then
  echo "No changed task files; nothing to import."
  exit 0
fi

qem_login

ok=0
failed=()
while IFS= read -r f; do
  f="${f%$'\r'}"
  [ -n "$f" ] || continue
  if qem_import_file "$f"; then
    ok=$((ok + 1))
  else
    failed+=("$f")
  fi
done <<< "$CHANGED_FILES"

echo "Imported: ${ok}   Failed: ${#failed[@]}"
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'Not imported: %s\n' "${failed[@]}" >&2
  exit 1
fi