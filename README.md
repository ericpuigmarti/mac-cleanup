# Disk Cleanup

A free, local macOS app that scans the usual places disk space quietly disappears and lets
you review and clear them — nothing is ever permanently deleted, everything goes to the
Trash first.

## What it scans

- **Caches & Logs** — `~/Library/Caches/*`, `~/Library/Logs/*`
- **Downloads** — files/folders over 50MB or untouched for 90+ days
- **Large Documents** — individual files over 100MB anywhere under `~/Documents`
- **Unused Applications** — apps in `/Applications` not opened in 6+ months (via Spotlight's last-used date)
- **Orphaned App Files** — leftover Application Support/Caches/Preferences/Containers folders whose
  app is no longer installed (heuristic, always shown as "possibly orphaned" — review before trashing)
- **Developer** — Xcode DerivedData, unavailable Simulator devices, SwiftPM/CocoaPods caches

## Memory

A separate "Memory" page (not disk-related) shows live RAM pressure (Normal/Under
Pressure/Critical), a Wired/Compressed/Active/Free breakdown, swap usage, and the top
memory-consuming processes. Real apps found via `NSWorkspace` get a **Quit** button (a normal
⌘Q-equivalent via `NSRunningApplication.terminate()`); background/helper processes are shown
for transparency but aren't individually quittable. There's deliberately no "free up RAM" or
"purge memory" button — macOS already reclaims memory on demand, and that kind of button is a
placebo in most "cleaner" apps. The in-app explainer says so directly.

There's also a menu bar icon (menu bar extra) with quick per-category and memory summaries —
see `plan.md` for a caveat about verifying it actually shows up in your menu bar.

## Safety

- Every deletion goes through `FileManager.trashItem` — items land in the Trash, never permanently
  deleted, until you empty it yourself.
- A hardcoded `SafetyGuard` only allows scanning/trashing paths under your home folder or
  `/Applications`, and blocks `/System`, `/Library`, `~/Library/Keychains`, `~/Library/Mail`, and
  `~/Library/Messages` outright.
- Removing an app from the Unused Applications list shows a distinct, more explicit confirmation
  than everything else.

## Running it

This Mac only has the Xcode Command Line Tools installed (no full Xcode.app), and `swift build`
needs a full Xcode install to find its platform SDK. So this project builds directly with `swiftc`
instead of SwiftPM — see `build.sh` for why. If you ever install full Xcode, `swift build` will
also work using the included `Package.swift`.

**Quick dev loop** (no app bundle, just compiles and runs):
```
./run.sh
```

**Build the real app**:
```
./build.sh
```
This produces `DiskCleaner.app` in this folder. It's ad-hoc signed (not notarized — this is a
personal tool, not something distributed through the App Store), so the first time you open it,
right-click it in Finder and choose Open instead of double-clicking, to get past Gatekeeper's
one-time warning. After that it opens normally.

Drag `DiskCleaner.app` into `/Applications` if you want it to stick around like a normal app.

## Notes

- The Developer category will legitimately show nothing on a machine without full Xcode installed
  (no DerivedData, no `simctl`) — that's expected, not a bug.
- Orphaned App Files is a heuristic based on bundle-ID-shaped folder names; it's meant as a lead to
  investigate, not something to blindly select-all and trash.
- See `plan.md` for what's shipped so far, known caveats, and ideas for future phases.
