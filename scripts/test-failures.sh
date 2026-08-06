#!/usr/bin/env bash
#
# Print the assertion messages for the most recent test run's failures.
#
# `xcodebuild test` (via `make test`) prints only "Failing tests: <name>" — the
# actual assertion ("Expectation failed: …") lives inside the .xcresult bundle.
# This surfaces it in one shot instead of re-running the suite.
#
# Usage: scripts/test-failures.sh [SCHEME]   (SCHEME defaults to Taskmato)
set -euo pipefail

SCHEME="${1:-Taskmato}"
results_glob="$HOME/Library/Developer/Xcode/DerivedData/${SCHEME}-*/Logs/Test/*.xcresult"

# Walk bundles newest-first and use the first READABLE one. A run that was
# killed mid-write leaves a corrupt bundle (missing Info.plist) that is newer
# than the last good result, so "newest" alone is not enough.
summary=""
chosen=""
for bundle in $(ls -dt $results_glob 2>/dev/null); do
  if out="$(xcrun xcresulttool get test-results summary --path "$bundle" 2>/dev/null)"; then
    summary="$out"
    chosen="$bundle"
    break
  fi
done

if [ -z "$summary" ]; then
  echo "No readable .xcresult found for scheme '$SCHEME'. Run 'make test' first." >&2
  exit 1
fi

echo "Result bundle: $chosen" >&2

printf '%s' "$summary" | python3 -c '
import sys, json

data = json.load(sys.stdin)
failures = data.get("testFailures", [])
if not failures:
    print("No failing tests in the latest result.")
else:
    for f in failures:
        print("✘ " + f.get("testName", "?"))
        print("    " + f.get("failureText", "").strip())
'
