#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 <consult.md|-> <response.txt|->" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 64
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI is not installed or not on PATH." >&2
  exit 69
fi

consult_file="$1"
response_file="$2"

if [[ "$consult_file" == "-" ]]; then
  consult_file="/dev/stdin"
elif [[ ! -r "$consult_file" ]]; then
  echo "Error: consult file is not readable: $consult_file" >&2
  exit 66
fi

if [[ "$response_file" == "-" ]]; then
  response_file="/dev/stdout"
fi

if [[ "$response_file" != "/dev/stdout" && -d "$response_file" ]]; then
  echo "Error: response path is a directory: $response_file" >&2
  exit 73
fi

if [[ "$response_file" != "/dev/stdout" && -e "$response_file" && "$consult_file" -ef "$response_file" ]]; then
  echo "Error: consult and response files must be different." >&2
  exit 64
fi

timeout_seconds="${FABLE_TIMEOUT_SECONDS:-420}"
effort="${FABLE_EFFORT:-high}"

if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: FABLE_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 64
fi

case "$effort" in
  low|medium|high|xhigh|max) ;;
  *)
    echo "Error: FABLE_EFFORT must be low, medium, high, xhigh, or max." >&2
    exit 64
    ;;
esac

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_seconds" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$timeout_seconds" "$@"
  else
    echo "Error: timeout, gtimeout, or perl is required." >&2
    return 69
  fi
}

run_consult() {
  run_with_timeout \
    claude --safe-mode -p \
    --model fable \
    --effort "$effort" \
    --permission-mode plan \
    --tools "Read,Grep,Glob,Agent" \
    --append-system-prompt "You are a read-only peer consultant (COO). You may use Read/Grep/Glob to ground your opinion in the actual code, and you may dispatch read-only subagents via the Agent tool for bounded evidence-gathering - you remain responsible for the integrated answer and must disclose what you delegated. You cannot edit or execute changes. Keep reads targeted to the paths the brief names plus a handful you judge load-bearing. Answer in the requested output contract with reasoned ideas and critique; do not promise future work or edits." \
    --no-session-persistence \
    < "$consult_file"
}

if [[ "$response_file" == "/dev/stdout" ]]; then
  run_consult
  exit 0
fi

response_dir="$(dirname -- "$response_file")"
if [[ ! -d "$response_dir" ]]; then
  echo "Error: response directory does not exist: $response_dir" >&2
  exit 73
fi

temp_response="$(mktemp "$response_dir/.fable-response.XXXXXX")"
cleanup() {
  rm -f -- "$temp_response"
}
trap cleanup EXIT HUP INT TERM

run_consult > "$temp_response"
mv -f -- "$temp_response" "$response_file"
trap - EXIT HUP INT TERM
