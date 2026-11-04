#!/usr/bin/env bash
# =============================================================================
# qem_lib.sh - shared helpers for the QEM scripts
#
# Purpose  : one place for everything that talks to Qlik Enterprise Manager (QEM).
# Use      : other scripts load it with "source"; it is never run on its own.
# Needs    : QEM_HOST    host name exactly as printed on QEM's certificate
#            QEM_SERVER  Replicate server name as registered in QEM
#            QEM_PAT, or QEM_USER + QEM_PASSWORD   the login (user@domain for AD)
# Provides : jqx                  jq that strips the CRLF line endings Windows adds
#            qem_login            signs in to QEM and sets SESSION
#            qem_list_task_names  prints the task names on QEM_SERVER
#            qem_stop_task        stops one task (StopTask)
#            qem_import_file      imports one tasks/<name>.json (ImportTask)
#            qem_export_task      exports one task without endpoints (ExportTask)
# =============================================================================

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

# Prints the names of all tasks on QEM_SERVER, one per line.
qem_list_task_names() {
  local tmp=".qem_tasklist.tmp"
  curl -sS -f --header "EnterpriseManager.APISessionID: ${SESSION}" \
    "${BASE}/servers/${QEM_SERVER}/tasks" -o "$tmp"
  jqx -r '.taskList[].name' "$tmp"
  rm -f "$tmp"
}

# Stops one task on QEM_SERVER. $1 = task name. STOP_TIMEOUT (seconds, default 60).
# Returns 0 when the task is stopped or was already stopped, 1 on any other failure.
qem_stop_task() {
  local task="$1" enc code resp
  enc=$(jqx -rn --arg t "$task" '$t|@uri')
  resp=".qem_stop_response.tmp"
  echo "Stopping ${task} on ${QEM_SERVER}"
  code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
    --header "EnterpriseManager.APISessionID: ${SESSION}" \
    --header "Content-Length: 0" \
    "${BASE}/servers/${QEM_SERVER}/tasks/${enc}?action=stop&timeout=${STOP_TIMEOUT:-60}")
  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
    echo "  Stopped (HTTP ${code})"
    rm -f "$resp"
    return 0
  fi
  if grep -q "AEM_TASK_ALREADY_STOPPED" "$resp"; then
    echo "  Already stopped"
    rm -f "$resp"
    return 0
  fi
  echo "  Could not stop (HTTP ${code}). QEM said:" >&2
  tr -d '\r' < "$resp" >&2 || true
  echo >&2
  rm -f "$resp"
  return 1
}

# Imports one task JSON file into QEM_SERVER. $1 = path to the file.
# Prints QEM's own error message when the import fails, and returns 1.
qem_import_file() {
  local f="$1" task enc code resp
  task=$(basename "$f" .json)
  enc=$(jqx -rn --arg t "$task" '$t|@uri')
  resp=".qem_import_response.tmp"
  echo "Importing ${task} into ${QEM_SERVER}"
  code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
    --header "EnterpriseManager.APISessionID: ${SESSION}" \
    --header "Content-Type: application/json" \
    "${BASE}/servers/${QEM_SERVER}/tasks/${enc}?action=import" \
    -T "$f")
  if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
    echo "  OK (HTTP ${code})"
    rm -f "$resp"
    return 0
  fi
  echo "  FAILED (HTTP ${code}). QEM said:" >&2
  tr -d '\r' < "$resp" >&2 || true
  echo >&2
  rm -f "$resp"
  return 1
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
