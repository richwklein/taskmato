# Diagnose a Failing Test

`make test` (which wraps `xcodebuild test`) reports **which** tests failed, but
not **why**. Its tail looks like:

```
Failing tests:
	TaskClipboardTests.readPayloadFallsBackToTitleOnlyWhenOnlyPlainTextIsPresent()

** TEST FAILED **
```

The actual assertion — `Expectation failed: (payload?.priority → .none) == (.none
→ nil)` — is written into the run's `.xcresult` bundle, not to stdout. Re-running
the suite to "see it again" wastes minutes and never surfaces the message. Read it
from the bundle instead.

## Fast path

```bash
make test-failures
```

This finds the most recent readable `.xcresult` under `~/Library/Developer/Xcode/
DerivedData/Taskmato-*/Logs/Test/` and prints each failure's test name and
assertion text. Run it right after a failed `make test`.

Sample output:

```
✘ TaskClipboardTests.readPayloadFallsBackToTitleOnlyWhenOnlyPlainTextIsPresent()
    Expectation failed: (payload?.priority → .none) == (.none → nil)
```

It skips corrupt bundles — a run that was interrupted mid-write leaves an
incomplete bundle that is *newer* than the last good result — and reports "No
failing tests in the latest result." when the newest good run was clean.

## Iterate on one test

Once you know the failing test, re-run just that suite instead of the whole
target — a single class against warm `DerivedData` takes seconds:

```bash
xcodebuild test \
  -project app/Taskmato.xcodeproj \
  -scheme Taskmato \
  -destination 'platform=macOS' \
  -only-testing:TaskmatoTests/TaskClipboardTests \
  CODE_SIGNING_ALLOWED=NO
```

Then `make test-failures` again to confirm the assertion is gone. Do a full
`make test` only once at the end.

## Under the hood

`make test-failures` runs [`scripts/test-failures.sh`](../../scripts/test-failures.sh),
which is just:

```bash
xcrun xcresulttool get test-results summary --path <bundle>
```

piped through a small JSON extractor for the `testFailures[].failureText` field.
To inspect a specific bundle directly, pass its path to that command.
