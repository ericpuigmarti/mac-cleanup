# Disk Cleanup — Plan

Working notes on what this app is, what's shipped, and what's open. This is a personal
macOS utility (Eric's own machine), not a product with users — treat "future phases" as
options to pull from when there's time, not a roadmap with deadlines.

## What this is

A free, local, native SwiftUI menu-bar-and-window utility that scans the usual places disk
space and RAM quietly disappear on a dev machine, and lets Eric review and clear them —
never destructively. Lives at `~/Documents/Claude/mac-cleanup`, separate from any other
project.

## Status: shipped

**Phase 1 — Disk scanning MVP**
- Six scan categories: Caches & Logs, Downloads, Large Documents, Unused Applications,
  Orphaned App Files, Developer (Xcode DerivedData, old Simulators, package manager caches)
- Everything routes through `FileManager.trashItem` (never permanent delete) and a
  `SafetyGuard` allowlist (only `$HOME` and `/Applications`, with `/System`, `/Library`,
  Keychains, Mail, Messages hard-blocked)
- Verified against the real machine: found real, sizeable clutter (Orphaned App Files alone
  was 65+ GB)

**Phase 2 — UX polish, "indie app" pass**
- Overview dashboard: hero reclaimable-space number, color-coded breakdown bar, clickable
  category list
- System Settings–style colored icon badges per category, reused across sidebar/dashboard/
  menu bar for visual consistency
- Custom app icon (procedurally generated gradient squircle, `Resources/AppIcon.iconset` →
  `AppIcon.icns`)
- Menu bar extra (`MenuBarExtra`, `.window` style): live reclaimable total, per-category
  breakdown, Scan All / Open / Quit
- Real macOS menu commands: ⌘R Scan All, ⌘⇧R rescan current page, ⌘A select all in category,
  ⌘⌫ move selected to Trash — all funnel through the same confirmation dialog as the button
- Right-click context menu on items: Reveal in Finder, Move to Trash…

**Phase 3 — Memory monitoring** (the "beyond disk space" ask)
- New "Memory" page (`MemoryView`) alongside the disk categories: live pressure read
  (Normal/Under Pressure/Critical, from `kern.memorystatus_vm_pressure_level`), a breakdown
  of Wired/Compressed/Active/Free (via `vm_stat` + `sysctl hw.memsize`), swap usage
- Top-memory-users list (via `top -l 1 -o mem`), cross-referenced against
  `NSWorkspace.runningApplications` so only real, regular foreground apps get a **Quit**
  button — helper/background processes are shown for transparency but aren't individually
  quittable (matches what's actually safe to act on)
- Quit uses `NSRunningApplication.terminate()` — a normal ⌘Q-equivalent, not a force-kill;
  the app never touches anything it can't safely undo by relaunching
- Deliberately **no "free up RAM" / "purge memory" button** — macOS already reclaims
  inactive/compressed memory on demand, and forcing a purge is a well-known "cleaner app"
  placebo that can make things slower. The app says this outright in-page instead of
  pretending to have a magic fix. The only real lever (closing the app that's holding the
  memory) is what's offered.
- Verified live on Eric's own machine mid-build: 8GB RAM, "Under Pressure", ~2.5GB swapped —
  concretely explains the earlier "out of application memory" dialog (Chrome + helpers were
  the big holders)

## How it's built

- Swift Package Manager layout (`Package.swift`, `Sources/DiskCleaner/`), but **built via
  `swiftc` directly** (`build.sh` / `run.sh`), not `swift build` — this machine only has
  Xcode Command Line Tools, and SwiftPM's `swift build` needs a full Xcode.app to resolve
  its platform SDK. `swift build` will also work if full Xcode ever gets installed; nothing
  needs to change for that to start working.
- Not sandboxed, ad-hoc signed (`codesign --sign -`) — fine for a personal tool run locally;
  first launch needs right-click → Open once to clear Gatekeeper.
- File layout: `Models/` (ScanCategory, ScanItem, ScanStore, SidebarSelection, MemoryInfo,
  ProcessMemoryInfo), `Scanners/` (one per category + SafetyGuard + SizeCalculator +
  MemoryMonitor), `Views/` (Overview, per-category list, Memory, sidebar, menu bar popover).

## Known limitations / caveats

- **Menu bar icon unverified visually.** The `MenuBarExtra` code is standard SwiftUI and
  `NSStatusItem` creation was confirmed to succeed (`isVisible: true`) via a direct AppKit
  test, but nothing rendered in screenshots taken during testing in the sandboxed dev
  environment used to build this (Dock and QuickLook thumbnailing showed similar gaps there
  too — looks like an environment quirk, not app code). **Needs a real check on Eric's
  actual Mac.**
- Orphaned App Files detection is a heuristic (matches bundle-ID-shaped folder names against
  currently-installed apps) — always surfaced as "possibly orphaned," never auto-selected.
- Top Memory Users lists individual processes, not per-app aggregates — a multi-process app
  like Chrome shows several helper rows plus one quittable "Google Chrome" row, rather than
  one rolled-up number the way Activity Monitor's default view does. This is more literally
  accurate but reads a little noisier; see Phase 4 ideas below if that's worth fixing.
- Ad-hoc signed only — fine for local use, would need a real Developer ID + notarization
  before sharing the built `.app` with anyone else.
- Hardcoded thresholds (Downloads: 50MB/90 days, Documents: 100MB, unused apps: 6 months) —
  not user-configurable yet.

## Open considerations for future phases

Rough ideas, unordered, pull from these opportunistically:

- **Aggregate memory by app**, not process — sum helper-process memory under their parent
  app (matches Activity Monitor's default view). Needs mapping helper PIDs to a parent app,
  which `top`/`ps` alone don't give cleanly; would need `proc_pid_rusage` + responsible-PID
  lookup or parsing `ps -axo pid,ppid`.
- **CPU/energy impact page** — same "beyond disk space" instinct as Memory: surface which
  apps are burning CPU/battery, again as an honest "here's what's using it, here's the safe
  action" page rather than a magic optimizer.
- **Launch Agents/Daemons audit** — `~/Library/LaunchAgents`, `~/Library/LaunchDaemons`,
  login items. Another common "silent buildup" spot, similar shape to Orphaned App Files.
- **node_modules / broader dev-tooling scan** — deliberately left out of Developer category
  v1 as unbounded/slow; could be an opt-in, explicitly-triggered deep scan.
- **Configurable thresholds** — expose the hardcoded size/age cutoffs as preferences instead
  of constants in each scanner.
- **Menu bar live badge** — once the menu bar icon itself is confirmed working, consider a
  lightweight periodic background refresh (careful: avoid turning this into a
  battery-draining always-on poller; on-demand is fine for a personal tool).
- **Distribution polish** — only relevant if this ever leaves Eric's machine: proper
  Developer ID signing, notarization, maybe a Sparkle-based auto-update check.
- **Scan history** — a running "reclaimed X GB total over time" stat, persisted locally.

## Decisions made (so future-me doesn't relitigate)

- Always Trash, never permanent delete — non-negotiable for a tool this blunt.
- No "purge RAM" button, ever — see Phase 3 rationale above. If asked to add one, point back
  here first.
- No sandboxing — this tool's entire job requires broad filesystem/process access; App
  Store distribution was never a goal.
- Build via `swiftc`/shell scripts, not Xcode project — keeps the whole thing scriptable and
  buildable from Claude Code without needing the Xcode GUI.
