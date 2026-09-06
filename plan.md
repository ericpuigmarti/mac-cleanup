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
- Verified against the real machine, fully scanned: **11.92 GB** reclaimable across all six
  categories (Caches 4.19GB, Downloads 3.01GB, Documents 178.9MB, Unused Apps 1.7GB, Orphaned
  1.18GB, Developer 2.27GB) — see Phase 4 for how the first pass at this number was wrong

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

**Phase 4 — v1 hardening: real bugs found by actually running it**

Building the feature is not the same as it being correct — every item below was caught by
scanning/trashing on the real machine, not by reading the code:

- **Sparse-file overstatement (the "65 GB" bug).** `SizeCalculator` originally summed logical
  file size (`.fileSizeKey`). A Docker Desktop VM disk image left behind under
  `~/Library/Containers/com.docker.docker` reported 64GB logically while occupying ~1GB on
  disk (`du` agreed: 1.0G). This made Orphaned App Files show 66GB when the honest, `du`-
  matching number is ~1.2GB. Fixed by switching to `.fileAllocatedSizeKey` (actual blocks) —
  **not** `.totalFileAllocatedSizeKey`, which is the clone-aware "total including
  clonefile-shared blocks" variant and does real I/O to detect APFS sharing; using it made a
  single Caches scan take 30–40s instead of ~8s for a correction that doesn't matter when
  you're summing independent files rather than asking if two share storage. `du` itself uses
  the same plain block-count approach — this now matches it.
- **False-positive orphans from helper bundle IDs.** `com.anthropic.claudefordesktop.ShipIt`
  (Sparkle's updater helper) was flagged as orphaned even though `com.anthropic.claudefordesktop`
  (Claude itself) is installed, because the match was exact-string only. Fixed: a candidate is
  now excluded if it matches an installed bundle ID *or* is `<installed-id>.anything` (covers
  `.ShipIt`, `.Sparkle`, and similar updater/helper sub-bundles).
- **Full Disk Access gap, discovered by actually trying to trash a Container.** macOS silently
  blocks any non-FDA app from writing to `~/Library/Containers/*` (other apps' sandbox
  containers) even though the same app can freely read sizes and list contents there — Cocoa
  surfaces this as `NSCocoaErrorDomain` 513. Before this fix, that failure just showed a bare
  "couldn't be moved" message. Now `ScanStore` detects this specific error and the alert offers
  an "Open Settings" button straight to Privacy & Security → Full Disk Access, with a plain-
  language explanation of why. This means: **Orphaned App Files entries under Containers can't
  actually be trashed until Eric grants Full Disk Access once** — everything else in the app
  (Caches, Downloads, Documents, DerivedData, Applications) doesn't need it.
- **Developer category was silently blind on this exact machine.** `xcrun simctl` (used to
  find "unavailable" Simulator devices precisely) ships with full Xcode.app, not the Command
  Line Tools — so on this CLT-only machine it fails outright, and Developer reported "nothing
  found" while `~/Library/Developer/CoreSimulator/Devices` actually held 2.1GB. Added a
  fallback: when `simctl` can't run (nil, not just empty), flag simulator device folders whose
  mtime is 60+ days old by reading `device.plist` for a friendly name. Found two real
  candidates on this machine (iPhone 15 Pro 1.48GB, iPhone 13 469.5MB, ~2 years untouched).
- **`ls ~/.Trash` from Terminal lies.** Verifying a trashed item actually landed in Trash via
  `ls -la ~/.Trash` intermittently returned "Operation not permitted" or a false-empty listing
  — Terminal itself needs Full Disk Access to enumerate `.Trash` directly, unrelated to this
  app. `osascript -e 'tell application "Finder" to get name of every item of trash'` is the
  reliable way to check from the command line (Finder owns Trash and doesn't need FDA to
  report on it). Worth remembering for any future debugging session, not just this one.

**Phase 5 — Safety education + "one-click, not a utility" simplification**

The ask: teach people what's actually safe to trash, and make the common case not require
understanding six categories first.

- **Every category now commits to one of three honest tiers** (`SafetyLevel`): 🟢 Safe to
  clean (Caches & Logs, Developer — regenerates automatically, zero data-loss risk), 🟡 Your
  files (Downloads, Large Documents — your own files, just flagged by size/age), 🟠 Review
  first (Unused Applications, Orphaned App Files — a real app removal or a heuristic guess).
  Same badge, same color, same three labels everywhere — Overview's category rows and every
  category's own page header.
- **Every category page now opens with a plain-language "why" callout** (`InfoCallout`,
  color-matched to its safety tier) explaining specifically why *this* category is safe or
  isn't — not a generic disclaimer, a real answer (e.g. Caches: "nothing here is a document,
  setting, or file you created"; Unused Apps: "you can always redownload or reinstall it
  later"). Memory's existing "why no purge button" note was refactored to use the same
  component for visual consistency.
- **One-click "Clean Safe Items"** on Overview — the new primary action, ahead of "Scan Every
  Category" (demoted to a secondary/bordered button). Auto-scans Caches & Logs + Developer if
  they haven't been scanned yet, then shows one combined confirmation across both, one Trash
  operation. This is the whole point: the common case no longer requires visiting six category
  pages and understanding what each one means first.
- **One-time dismissible "How to read this" banner** on first launch (`@AppStorage`-backed),
  explaining the three-tier system once and then staying out of the way for good.
- Refactored the trash-execution loop (`ScanStore.trash(_:)`) so `trashSelected()` and the new
  `confirmCleanSafeItems()` share one implementation — same SafetyGuard re-check, same Full
  Disk Access detection, no duplicated logic to drift out of sync.
- The shared "couldn't move to Trash" / Full Disk Access alert moved from `SummaryBarView` up
  to `ContentView` (`TrashErrorAlert` view modifier), since Clean Safe Items can now trigger it
  from Overview, not just from a category page.
- **Real bug caught mid-build, reproduced and confirmed fixed**: adding
  `.fixedSize(horizontal: false, vertical: true)` to the new `InfoCallout`'s `Text` — a
  normally-safe SwiftUI idiom — produced a degenerate layout specifically on `ItemListView`
  (sidebar rows went blank, header content shifted to negative Y off-screen, footer pushed to
  y≈1430 in a 600pt window) once combined with the page's `Spacer()`-based empty state and no
  explicit height anchor on the root `VStack`. Fixed two ways: removed the unneeded `fixedSize`
  (Memory's original explainer never needed it either), and added
  `.frame(maxHeight: .infinity, alignment: .top)` to `ItemListView`'s root `VStack` so any
  future page-level view is anchored against the real available height instead of inferring it
  from children.
- **Testing note, not an app bug**: mid-session, directory enumeration (`SizeCalculator`'s use
  of `FileManager`'s `NSURLDirectoryEnumerator`) started blocking indefinitely inside the
  kernel `open()` syscall on `~/Library/Caches` and, later, even `~/Downloads` — 0.0% CPU,
  sustained, reproducible with the scanner code untouched. Confirmed via `sample` (blocked in
  `open`, not a Swift-level deadlock) and, decisively, by running plain `du -sh ~/Library/Caches`
  from Terminal at the same time — it hung too. Since a completely unrelated Unix command hung
  identically, this is an environment/sandbox filesystem stall in the computer-use test session
  used to build this, not a bug in the app (consistent with the menu-bar-icon gap already noted
  below — this test environment has now shown two independent low-level quirks). **Re-verify
  the full Clean Safe Items flow on Eric's actual Mac** before trusting it end-to-end; the parts
  reachable before the stall (badges, callouts, confirmation copy, scan-then-confirm sequencing,
  the layout fix itself) were all confirmed working by direct reproduction.

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

- **Menu bar icon still unverified visually**, re-checked in this session too — the
  `MenuBarExtra` scene is standard SwiftUI, and the app runs and responds fine, but no icon
  appears in the menu bar's right-side status area in screenshots from this dev/test
  environment (checked again after a full rebuild — still absent). Given two independent
  sessions have hit the same gap in what appears to be a sandboxed/virtualized test
  environment rather than a real Mac, this is most likely still an environment quirk — but it
  genuinely has not been confirmed working anywhere. **Needs a real check on Eric's actual
  Mac** before relying on it; if it's also missing there, the menu bar feature needs its own
  debugging pass.
- **"Clean Safe Items" end-to-end trash confirmation not fully verified live** — same test
  environment, different quirk this time: mid-session directory enumeration started hanging
  indefinitely (confirmed environment-wide via plain `du` hanging too, not an app bug — see
  Phase 5). Everything up to and including the scan-then-confirm sequencing was verified
  working by direct reproduction; the actual Trash operation for this specific one-click path
  should get a real run on Eric's Mac before being trusted blind. `trashSelected()` (the
  per-category path) IS fully verified live, including the Full Disk Access failure case, and
  `confirmCleanSafeItems()` shares its exact trash-execution code.
- **Full Disk Access required for one specific case**: trashing Orphaned App Files entries
  that live under `~/Library/Containers/*` (other apps' sandbox containers). Everything else
  works without it. The app now explains this and offers a direct link to the right System
  Settings pane when it happens, rather than a bare error.
- Orphaned App Files detection is a heuristic (matches bundle-ID-shaped folder names against
  currently-installed apps, now also excluding `<installed-id>.helper-name` sub-bundles) —
  always surfaced as "possibly orphaned," never auto-selected.
- Developer category's stale-simulator detection falls back to a 60-day-unmodified heuristic
  on machines without full Xcode (`simctl` unavailable) — less precise than the real
  "unavailable" check Xcode.app would give (a simulator just idle for 2 months isn't
  necessarily broken, just unused), but still an honest, clearly-labeled signal rather than
  silently finding nothing.
- Top Memory Users lists individual processes, not per-app aggregates — a multi-process app
  like Chrome shows several helper rows plus one quittable "Google Chrome" row, rather than
  one rolled-up number the way Activity Monitor's default view does. This is more literally
  accurate but reads a little noisier; see "Open considerations" below if that's worth fixing.
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
- Size everything with `.fileAllocatedSizeKey`, never `.totalFileAllocatedSizeKey` — the
  latter's clone-aware accounting is both unnecessary here and a real, measured 4-5x scan
  slowdown. If a future accuracy complaint mentions clonefile/shared storage specifically,
  reconsider deliberately; don't switch back by default.
