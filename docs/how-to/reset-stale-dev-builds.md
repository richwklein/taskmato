<!-- cspell:words DerivedData lsregister deriveddata Frameworks LaunchServices richwklein worktree worktrees -->
# How to clear stale dev builds and fix `taskmato://` routing

Use this runbook when a `taskmato://` invocation (via `scripts/taskmato`) appears to hit an
**old build** — for example, a change you just made is not reflected, or the URL launches an
unexpected copy of the app.

## Why this happens

Every Debug build lands in a per-project-path `DerivedData` folder, so each git worktree
produces its **own** `Taskmato.app`. They all share the bundle id `com.richwklein.Taskmato`
and all register a claim on the `taskmato:` URL scheme. `scripts/taskmato` ends in
`open "taskmato://…"`, which lets **LaunchServices** pick one of those registered copies —
with no guarantee it is the build you just made.

The result: dozens of registered handlers accumulate over time, and URL events route to a
stale (or deleted) bundle.

## Diagnose

```bash
# How many copies of the scheme are registered
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -dump | grep -c "claimed schemes:.*taskmato:"

# Which registered Taskmato bundles still exist on disk (should be exactly one)
"$LSREG" -dump | grep -oE "/[^ ]*Taskmato\.app" | sort -u | while read -r p; do
  [ -e "$p" ] && echo "EXISTS: $p"
done
```

If more than one path `EXISTS`, or the surviving path is not your current worktree's build,
run the cleanup.

## Clean up

```bash
# 1. Quit any running (possibly stale) instances
killall Taskmato 2>/dev/null

# 2. Remove every Taskmato build product across all worktrees
#    (safe — DerivedData is regenerated on the next build; `make clean` only cleans the
#    current worktree, so use this glob to catch the others)
rm -rf ~/Library/Developer/Xcode/DerivedData/Taskmato-*

# 3. Rescan LaunchServices so deleted bundles drop out of resolution
#    (the old `-kill` flag was removed on recent macOS; a plain rescan is enough because
#    LaunchServices skips registrations whose bundle no longer exists on disk)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -r -domain local -domain system -domain user

# 4. Rebuild the current worktree and launch it once so it re-registers as the handler
make build
open "$(find ~/Library/Developer/Xcode/DerivedData -path '*/Build/Products/Debug/Taskmato.app' -maxdepth 6 | head -1)"
```

After step 4 the freshly built app is the only `Taskmato.app` on disk, so `taskmato://`
resolves to it. Dangling registrations may still appear in `lsregister -dump`; they are
harmless because LaunchServices ignores registrations whose bundle is missing.

## Prevent recurrence

Because every worktree builds the same bundle id, building a second worktree re-introduces
the ambiguity. Either keep only one build on disk (delete other worktrees' DerivedData as
you go), or pin the wrapper to a specific build so LaunchServices never guesses — see the
`open` call in `scripts/taskmato`.
