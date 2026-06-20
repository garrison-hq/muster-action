#!/usr/bin/env bash
# Run muster and translate its result into GitHub Action outputs + annotations.
# Inputs arrive as env vars set by action.yml (MA_*, MUSTER_A2A_*).
# The token is never echoed or written anywhere.
set -uo pipefail

# Empty endpoint/token must be UNSET (not ""), so muster's absent-endpoint skip
# path triggers (an empty string is not "absent").
[ -z "${MUSTER_A2A_ENDPOINT:-}" ] && unset MUSTER_A2A_ENDPOINT
[ -z "${MUSTER_A2A_TOKEN:-}" ] && unset MUSTER_A2A_TOKEN

VERSION="${MA_VERSION:-latest}"
PKG="@garrison-hq/muster@${VERSION}"
OUT="$(mktemp)"

# Run the human-readable report (no --json) so the Actions log is readable and the
# failure annotation has real content. Capture stdout+stderr together: muster writes
# success reports to stdout and error reports to stderr, and we want either.
# shellcheck disable=SC2086  # MA_COMMAND/MA_ARGS are intentionally word-split into argv.
npx -y "$PKG" ${MA_COMMAND} ${MA_ARGS} >"$OUT" 2>&1
CODE=$?

echo "----- muster ${MA_COMMAND} ${MA_ARGS} (exit ${CODE}) -----"
cat "$OUT"
echo "----------------------------------------------------------"

# Classify from the exit code (muster's contract), refining 0 into skipped vs passed.
case "$CODE" in
  0) if grep -qiE '(^|[^a-z])skip' "$OUT"; then RESULT="skipped"; else RESULT="passed"; fi ;;
  1) RESULT="failed" ;;
  *) RESULT="errored" ;;
esac

# On failure, emit one inline workflow annotation summarizing the report, attributed
# to the manifest file when an argument is a real path (D3).
if [ "${MA_ANNOTATIONS:-true}" = "true" ] && [ "$CODE" -ne 0 ]; then
  file=""
  for a in ${MA_ARGS}; do
    if [ -f "$a" ]; then file="$a"; break; fi
  done
  # Workflow commands are single-line: escape % then collapse CR/LF to spaces.
  summary="$(head -c 900 "$OUT" | sed 's/%/%25/g' | tr '\r\n' '  ')"
  [ -z "$summary" ] && summary="exited ${CODE}"
  if [ -n "$file" ]; then
    echo "::error file=${file}::muster ${MA_COMMAND}: ${summary}"
  else
    echo "::error::muster ${MA_COMMAND}: ${summary}"
  fi
fi

{
  echo "exit-code=${CODE}"
  echo "result=${RESULT}"
} >>"$GITHUB_OUTPUT"
echo "muster result: ${RESULT} (exit ${CODE})"

rm -f "$OUT"

# fail-on: 'error' (default) fails the job on a non-zero muster exit; 'never' reports only.
if [ "${MA_FAIL_ON:-error}" = "error" ] && [ "$CODE" -ne 0 ]; then
  exit "$CODE"
fi
exit 0
