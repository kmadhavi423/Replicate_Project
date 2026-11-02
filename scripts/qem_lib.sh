#!/usr/bin/env bash
# Shared helpers for the QEM scripts. Source this file; do not run it.
# Required env: QEM_HOST, QEM_SERVER, and either QEM_PAT or QEM_USER + QEM_PASSWORD.

BASE="https://${QEM_HOST}/attunityenterprisemanager/api/v1"

# jq on Windows can end lines with CRLF. Strip it so values and files stay LF-only.
jqx() { jq "$@" | tr -d '\r'; }

# Logs in to QEM and sets SESSION.
qem_login() {
  local cred auth hdrs
  if [ -n "${QEM_PAT:-}" ]; then
    cred="api-token:${QEM_PAT}"                       # OpenID Connect
  else
    [ -n "${QEM_USER:-}" ] && [ -n "${QEM_PASSWORD:-}" ] || {
      echo "Set QEM_PAT, or both QEM_USER and QEM_PASSWORD" >&2; exit 1; }
    cred="${QEM_USER}:${QEM_PASSWORD}"                # Active Directory, QEM_USER = user@domain
  fi
  auth=$(printf '%s' "$cred" | base64 -w0)
  hdrs=$(curl -sS -D - -o /dev/null \
    --header "Authorization: Basic ${auth}" "${BASE}/login")
  SESSION=$(printf '%s\n' "$hdrs" \
    | awk -F': ' 'tolower($1)=="enterprisemanager.apisessionid"{print $2}' \
    | tr -d '\r')
  if [ -z "$SESSION" ]; then
    echo "QEM login failed. Response: $(printf '%s\n' "$hdrs" | head -1 | tr -d '\r')" >&2
    exit 1
  fi
  echo "::add-mask::$SESSION"
}

# Imports one task JSON file into QEM_SERVER. $1 = path to the file.
qem_import_file() {
  local f="$1" task enc
  task=$(basename "$f" .json)
  enc=$(jqx -rn --arg t "$task" '$t|@uri')
  echo "Importing ${task} into ${QEM_SERVER}"
  curl -sS -f -X POST \
    --header "EnterpriseManager.APISessionID: ${SESSION}" \
    --header "Content-Type: application/json" \
    "${BASE}/servers/${QEM_SERVER}/tasks/${enc}?action=import" \
    -T "$f"
  echo
}

# Exports one task from QEM_SERVER, without endpoints, to tasks/<name>.json. $1 = task name.
qem_export_task() {
  local task="$1" enc tmp
  enc=$(jqx -rn --arg t "$task" '$t|@uri')
  tmp=".qem_export.$$.tmp"
  echo "Exporting ${task} from ${QEM_SERVER}"
  curl -sS -f --header "EnterpriseManager.APISessionID: ${SESSION}" \
    "${BASE}/servers/${QEM_SERVER}/tasks/${enc}?action=export&withendpoints=false" \
    -o "$tmp"
  mkdir -p tasks
  jqx -S . "$tmp" > "tasks/${task}.json"
  rm -f "$tmp"
}
