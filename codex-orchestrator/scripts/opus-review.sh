#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  echo "Usage: $0 <review.md|-> <response.txt|->" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 64
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude CLI is not installed or not on PATH." >&2
  exit 69
fi

review_file="$1"
response_file="$2"

if [[ "$review_file" == "-" ]]; then
  review_file="/dev/stdin"
elif [[ ! -r "$review_file" ]]; then
  echo "Error: review file is not readable: $review_file" >&2
  exit 66
fi

if [[ "$response_file" == "-" ]]; then
  response_file="/dev/stdout"
fi

if [[ "$response_file" != "/dev/stdout" && -d "$response_file" ]]; then
  echo "Error: response path is a directory: $response_file" >&2
  exit 73
fi

if [[ "$response_file" != "/dev/stdout" && -e "$response_file" && "$review_file" -ef "$response_file" ]]; then
  echo "Error: review and response files must be different." >&2
  exit 64
fi

timeout_seconds="${OPUS_REVIEW_TIMEOUT_SECONDS:-420}"
effort="${OPUS_REVIEW_EFFORT:-high}"

if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: OPUS_REVIEW_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 64
fi

case "$effort" in
  low|medium|high|xhigh|max) ;;
  *)
    echo "Error: OPUS_REVIEW_EFFORT must be low, medium, high, xhigh, or max." >&2
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

run_review() {
  run_with_timeout \
    claude --safe-mode -p \
    --model opus \
    --effort "$effort" \
    --permission-mode plan \
    --tools "Read,Grep,Glob" \
    --append-system-prompt "You are Claude Opus 5 acting as an independent, fresh-context quality gate. Do not invoke orchestration skills, delegate, edit files, or rewrite the artifact. Use read/search tools only to inspect the named paths. Challenge correctness, completeness, evidence, safety, and acceptance criteria. Return PASS, CHANGES_REQUIRED, or BLOCKED; review scope; findings ordered by severity with exact evidence; unsupported claims; validation gaps; smallest required changes; residual risk; and what should remain unchanged. A PASS requires concrete review evidence." \
    --no-session-persistence \
    < "$review_file"
}

if [[ "$response_file" == "/dev/stdout" ]]; then
  run_review
  exit 0
fi

response_dir="$(dirname -- "$response_file")"
if [[ ! -d "$response_dir" ]]; then
  echo "Error: response directory does not exist: $response_dir" >&2
  exit 73
fi

temp_response="$(mktemp "$response_dir/.opus-response.XXXXXX")"
cleanup() {
  rm -f -- "$temp_response"
}
trap cleanup EXIT HUP INT TERM

run_review > "$temp_response"
mv -f -- "$temp_response" "$response_file"
trap - EXIT HUP INT TERM
