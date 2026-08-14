# SDD ledger — plan: docs/superpowers/plans/2026-08-13-plugin-architecture.md

Spec: docs/superpowers/specs/2026-08-13-plugin-architecture-design.md (read, binding authority)
Branch: claude/super-app-plugin-architecture-f4df89
Plan BASE: 15b2e3cb51ed8ed293bfae33e05344d3468030ce
SIM_UDID verified: C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF (iPhone 17, iOS 26.5) — booted

## Pre-flight scan

Shared files / interfaces across tasks:

| Tasks | produces → consumes | finding |
|---|---|---|
| 1 → 3 → 4 | `ExampleRootView.swift`: T1 creates, T3 overwrites whole file, T4 edits 3 places | clean — T4's anchors (`saveError`, `Section("Signed in as")`, `.task {`) all exist in T3's version |
| 1 → 5 | `FeatureRegistry.swift`: T1 creates with one entry, T5 empties it | clean |
| 1 → 4 | `null_appApp.swift`: T1 rewrites `.signedIn` case, T4 adds `init()` | clean — disjoint regions |
| 1 → 3 | `ExampleRootView(userID:)` init signature | clean — T3 keeps the same signature |
| 2 → 3 | `f_example.note(user_id, body)` → `ExampleNote` CodingKeys | clean — column names match |
| 2 → 5 | schema created → `drop schema f_example cascade` | clean |
| 4 → 4 | `sweepOrphans(installed:root:defaults:)` → harness call + `null_appApp` call | clean — both match the signature |
| 4 → 5 | `#if !DEBUG` gate → T5 Step 11 verification | clean — T5 explicitly builds `-configuration Release` |

Per-task self-consistency:

| Task | own text agrees with itself? |
|---|---|
| 1 | yes — Step 11 greps only core files for a feature name; `ExampleFeature` lives under `Features/` |
| 2 | yes — Step 4 relies on `set local role` persisting across `set_config` in one transaction, which is correct |
| 3 | yes — but carries a hard external dependency (Dashboard) noted below |
| 4 | yes — Step 3 requires the harness to FAIL to compile first, which proves the harness tests real code |
| 5 | yes — Step 13's `grep -ri example null-app/` verified to return nothing today (exit 1), so the expectation is reachable |

Scan verdict: no conflicts requiring a ruling before Task 1.

Known external dependency (not a conflict): Task 3 Step 1 needs the human to add
`f_example` to Exposed schemas in the Supabase Dashboard; Task 5 Step 10 needs it removed.
MCP has no tool for this setting.

## Progress

Task 1: dispatched (implementer, sonnet) — BASE 15b2e3c
Task 1: implementer DONE — commit 22ddaec. Both platform builds clean; on-screen uuid
  68dab439-9cb8-443e-8f16-6ed68abe1129 matched the profiles row; core-file grep exit 1.
  Implementer concerns: (a) simulator text entry is unreliable in this environment — MCP tap
  did not focus fields, computer-use keyboard blocked; worked around with on-screen keyboard
  clicks. Expect the same friction in Tasks 3-5. (b) a real account display_name="tester"
  was created on the live Supabase project during verification and left in place.
Task 1: task reviewer dispatched (sonnet) — diff 15b2e3c..22ddaec
Task 1: review ✅ spec compliant, quality Approved. 0 Critical, 0 Important, 2 Minor.
  Reviewer independently opened both screenshots and confirmed the on-screen uuid is
  character-identical to the profiles row — genuine screen-to-database evidence.
Task 1: minor (deferred): test account display_name="tester" left on the live Supabase
  project; wants a deliberate cleanup pass before it accumulates across later tasks.
Task 1: minor (deferred): HomeView.swift:179 feature tiles have no combined
  icon+title accessibility label (not requested by the brief).
Task 1: ⚠️ resolved by controller — reviewer could not confirm the zero-warning claim.
  Re-ran both builds: `** BUILD SUCCEEDED **`, no warning:/error: lines on either platform
  after excluding AppIntents boilerplate.
Task 1: complete (commits 15b2e3c..22ddaec, review clean)

Ruling: Task 2 Step 7 and Task 5 Step 15 instruct the implementer to write results into
  `.superpowers/sdd/<plan>/progress.md` — that is this controller-owned ledger, and a
  subagent writing it would corrupt the recovery state the whole process depends on.
  Both tasks will instead write to their own `task-N-report.md`, and I fold the results
  into the ledger myself. Cost if wrong: none material — the same information lands in the
  same workspace, one file over.
Task 2: dispatched (implementer, sonnet) — BASE 22ddaec, SQL-only via Supabase MCP
Task 2: implementer DONE_WITH_CONCERNS — migration `f_example_note` applied, no repo commits.
  Refusal proof: owner select = 1; stranger select/update/delete = 0/0/0; forged insert errored
  with `new row violates row-level security policy for table "note"`; 0 cross-schema FKs into
  f_example; table empty afterwards; git status clean.
  Concern: brief Step 2's `order by created_at limit 1` returned 551a2f7a-… ("Purin Tae"), not
  the 68dab439-… ("tester") account I named in the dispatch — tester is the newest of four real
  users, not the oldest. Assessed as benign: the refusal proof is valid for any real user id,
  and the implementer correctly followed the query result over my prose. No fix needed.

Ruling: Task 2 produced no git diff by design (SQL-only), so the task review cannot be
  diff-based. The artifact under review is the live database plus the report. I am dispatching
  the task reviewer with no diff file and read-only database verification instead of skipping
  the review gate. Cost if wrong: a review that inspects schema state rather than a patch —
  weaker at catching stray edits, which `git status` clean already covers.
Task 2: task reviewer dispatched (sonnet) — no diff; live-schema verification
Task 2: review ✅ spec compliant, quality Approved. 0 Critical, 0 Important, 1 Minor.
  Reviewer read the live policy definitions rather than the report: WITH CHECK present on both
  insert and update (the gap that would allow forged rows), FK is
  `REFERENCES auth.users(id) ON DELETE CASCADE`, rls_enabled true, 0 rows left, migration
  `20260813171327_f_example_note` in history. Also independently confirmed 551a2f7a-… really is
  the oldest auth.users row, so the implementer's Step 2 concern was a correct literal reading.
Task 2: minor (deferred, plan-mandated): grants give insert/update/delete on f_example.note to
  `anon` as well as `authenticated`. Inert today — user_id is NOT NULL and auth.uid() is NULL for
  anon, so the policy can never be satisfied — but broader than needed. Came verbatim from the
  brief's SQL, so it is a plan defect, not an implementer choice. Worth narrowing to
  `authenticated` in the template future features copy.
Task 2: ⚠️ noted — reviewer could not verify Exposed schemas (not a SQL-level setting; the
  authenticator role carries no pgrst.db_schemas override). That is exactly Task 3 Step 1 and is
  the human-only step. Not a Task 2 gap.
Task 2: complete (no commits — SQL only; migration f_example_note, review clean)

Ruling: PLAN DEFECT found while helping the user locate the setting — Supabase docs
  (troubleshooting PGRST002) state a schema must be removed from Exposed schemas BEFORE it is
  dropped. Task 5 had the reverse order (Step 8 drop, Step 10 unexpose), which would have made
  PostgREST fail its schema-cache build and return PGRST002 for EVERY request in the project,
  core `public.profiles` included — the throwaway feature's removal would have taken the whole
  app down until someone edited a dashboard setting. Fixed in both spec and plan: unexpose is
  now Step 8 (with a curl check), drop is Step 9, and Step 10 verifies the Data API still
  serves `public` with HTTP 200. Task-5 brief regenerated. Cost if wrong: none — the new order
  is strictly safer and the docs are explicit.
  Confirmed current state empirically: REST returns PGRST106
  "Only the following schemas are exposed: public, graphql_public".

Task 3: was BLOCKED on human action — Exposed schemas. Resolved after two wrong turns worth
  recording: the setting has moved to Project Settings → Integrations → Data API → **Settings**
  tab (not the "API" page), and the page has two similar-looking fields — the user first added
  f_example to **Extra search path** instead of **Exposed schemas**, which fails silently.
  Now verified working: REST GET on f_example.note returns HTTP 200 `[]`, and public.profiles
  still returns 200, so the schema-cache rebuild did not disturb core.
Task 3: dispatched (implementer, sonnet) — BASE 86cc144
Task 3: implementer DONE — commit 7642016. Typed "hello from task 3" in the app; DB read-back
  returned {68dab439-…, "hello from task 3"}; after terminate/relaunch the field repopulated
  from the server. Both builds clean, diff confined to Features/Example/.
  Technique note for later tasks: the iOS Simulator MCP `text` action DOES type reliably in one
  call — Task 1's key-by-key workaround was unnecessary. Tap coordinates must be converted from
  screenshot pixels to device points (~0.437 scale).
Task 3: task reviewer dispatched (sonnet) — diff 86cc144..7642016
Task 3: review ✅ spec compliant but quality NEEDS FIXES. 0 Critical, 2 Important (both
  plan-mandated — the defective code came verbatim from my own plan), 2 Minor.
  Reviewer independently re-ran the read-back SQL, checked information_schema.columns to confirm
  all three columns are NOT NULL (so the synthesized Encodable really is safe from the
  encodeIfPresent trap), and confirmed the PK makes the upsert a true single-row overwrite.
  Important 1 — ExampleRootView `.task` assigns `draft = store.body` after an async load,
    clobbering anything the user typed while the load was in flight.
  Important 2 — ExampleStore.load() swallows every error and leaves body = "", indistinguishable
    from "no note yet". Combined with an unconditional upsert on a PK'd row, an offline open
    followed by a save silently destroys the previously saved note.

Ruling: FIX both rather than park them, even though ExampleFeature is deleted in Task 5.
  Reasoning: the plan's own closing section tells future readers to recover
  `Features/Example/` from git history as the reference for building a real feature, so the
  reviewer's "this becomes a copy-paste template" concern is not hypothetical — I invited it.
  Directed approach: keep the field non-editable until the first load resolves, and make load
  failure a distinct state that surfaces to the user and blocks Save, instead of masquerading
  as an empty note. Cost if wrong: one fix round spent on code that gets deleted at the end of
  this plan; the alternative cost is shipping a data-loss pattern as the documented example.
  Note: this makes the delivered ExampleRootView/ExampleStore diverge from the plan's Task 3
  code blocks. Git is the record; I am not rewriting an already-executed task's plan text.
Task 3: fix round 1/5 dispatched — resumed the original implementer with both findings verbatim
Task 3: fix round 1/5 (2 addressed, 0 open; commits 7642016..ca66571). Re-reviewer confirmed the
  TextField is `.disabled(isLoading)` until `.task` resolves, and `loadFailed` (set in a real
  do/catch) hard-gates Save. It also ruled the offline substitution sufficient, with a reason I
  accept: the catch is untyped and unconditional, so a URLError from a genuine offline device
  reaches the identical code path the schema-misconfig test exercised.
Task 3: minor (deferred, from Task 2's schema): `f_example.note.updated_at` only gets its default
  on INSERT — an upsert-driven UPDATE leaves it stale. No BEFORE UPDATE trigger exists. Belongs
  to the schema, not to Task 3's code.
Task 3: complete (commits 86cc144..ca66571, review clean after 1 fix round)

Ruling: CROSS-TASK CONFLICT caught at dispatch. Task 4 Step 5 tells the implementer to replace
  the `.task { }` block of ExampleRootView with a version ending in `ExampleRootView.recordVisit()`
  — text written before Task 3's fix existed. Applying it verbatim would delete the
  `isLoading = false` line, leaving the TextField permanently disabled and silently reverting the
  Task 3 fix that just passed review. Directed: Task 4 must MERGE recordVisit() into the existing
  `.task`, preserving every line Task 3 added, and must verify the field is still typable on the
  simulator. Cost if wrong: none — the alternative is shipping a dead text field.
Task 4: dispatched (implementer, sonnet) — BASE ca66571
Task 4: implementer DONE_WITH_CONCERNS — commit ac5687e. Harness went RED
  (`cannot find 'FeatureStorage' in scope`) then GREEN 5/5; both builds clean; Step 8 found
  last-visit.txt and f.example.showsUUID on device; text field still typeable, so the Step 5
  merge ruling held and Task 3's fix survived.
  CONCERN THAT MUST REACH TASK 5: simply visiting the Example screen does NOT create the
  `f.example.showsUUID` key. `@AppStorage` writes only on an actual set, and the on-disk plist
  does not materialise until the app backgrounds or terminates. The implementer had to toggle
  the switch and background the app to produce the leftover at all. If Task 5 assumes a plain
  visit is enough, its sweep verification proves nothing — it would "confirm" the sweep removed
  a key that never existed. Carry this into the Task 5 dispatch.
Task 4: task reviewer dispatched (sonnet) — diff ca66571..ac5687e
Task 4: review ✅ spec compliant, quality Approved. 0 Critical, 0 Important, 2 Minor.
  Reviewer proved the Step 5 merge ruling held from the diffstat alone: 3 deletions, all of them
  the old Text lines replaced by the Toggle; `isLoading = false` appears as an unchanged context
  line in the .task hunk, and `.disabled(isLoading)` / the loadFailed section sit outside every
  hunk. Nothing Task 3 added was reverted. Also walked sweepOrphans' input space: missing root,
  malformed `f.` keys, core keys, and mutation-during-iteration all handled.
Task 4: minor (deferred): `defaultsKey(_:_:)` has no caller — ExampleRootView hardcodes the
  literal "f.example.showsUUID" (brief-mandated). Latent drift risk for features that copy the
  pattern without routing through the helper.
Task 4: minor (deferred): task-4-report asserts BUILD SUCCEEDED without pasting xcodebuild output
  the way the harness steps did.
Task 4: ⚠️ x2 resolved by controller — re-ran both builds myself: `** BUILD SUCCEEDED **`, no
  warning:/error: lines on either platform. All 7 referenced screenshots exist under
  workspace/screenshots/ (my first check mangled the paths on the space in "App Project").
Task 4: complete (commits ca66571..ac5687e, review clean)

Task 5: dispatched (implementer, sonnet) — BASE ac5687e, STEPS 1-7 ONLY. Split deliberately:
  Step 8 needs the human to remove f_example from Exposed schemas, and a subagent parked waiting
  on a human is wasted. Agent stops after Step 7; I coordinate the dashboard step and resume it
  for Steps 8-15. Carried the Task 4 @AppStorage concern into the dispatch as a baseline the
  agent must capture BEFORE deleting anything.
Task 5 (steps 0-7): DONE — commit 4f1402c (docs only; the removal itself is still uncommitted in
  the working tree, as instructed).
  ** THE LOAD-BEARING RESULT: both platforms built clean with ONLY Features/Example/ deleted and
  one line removed from FeatureRegistry.swift. No other file needed a single change. HomeView
  fell straight through to its existing empty state. The architecture's central claim holds. **
  Baseline captured before deletion: Features/example/last-visit.txt and f.example.showsUUID both
  genuinely present, produced via a real UI toggle (agent had to work around a stale cfprefsd
  cache in the simulator and documented it rather than papering over it).
  Concerns: (1) the data container UUID changed on reinstall mid-session; (2) SAME VACUOUS-TEST
  CLASS AS BEFORE — the `appearance` key is not in the plist at all, because nobody has touched
  the theme picker. Step 11's "the sweep leaves core keys alone" check would therefore verify
  nothing. Must set a theme in Settings before running the sweep verification.
Task 5: human step done. Verified myself: f_example → PGRST106 ("Only the following schemas are
  exposed: public, graphql_public"), profiles → HTTP 200. Recorded as Step 8's evidence.
Task 5: resume of the original implementer FAILED — "No transcript found". Dispatched a fresh
  implementer for Steps 9-15 instead, carrying the state and the surviving report file. This is
  exactly why implementers write reports to disk rather than only returning them: the agent died,
  the memory did not.
Task 5 (steps 9-15): DONE — commit ce050ba. All four clean-removal criteria PASS.
  1. build both platforms, only the two permitted paths changed — PASS
  2. drop schema f_example cascade — PASS (schema gone, profiles still 4 rows, REST 200)
  3. Release-build sweep — PASS against a genuine before/after:
       before { appearance: dark, f.example.showsUUID: true } + Features/example/last-visit.txt
       after  { appearance: dark } + empty folder
     The agent acted on the prior task's warning and wrote `appearance` for real first, so the
     "core key survived" half of the assertion is non-vacuous.
  4. grep -ri example null-app/ — PASS (no output, exit 1)
Task 5: task review ❌→ 0 Critical, 1 Important, 2 Minor. The Important is a false positive
  against the implementer and a true one against me:

Ruling: the Important finding says brief Step 15 (write results into progress.md) was skipped.
  The implementer was right to skip it — my own earlier ruling forbade subagents writing this
  ledger, and I never told the reviewer that. But the reviewer is correct that the ledger was
  stale and would have misled a future reader into thinking Task 5 was still blocked. The gap was
  mine, not the implementer's, and this entry closes it. No fix round: nothing in the deliverable
  changes. Cost if wrong: none.
Task 5: minor (carried to final fix wave): UNINSTALL-template.md step 5 says to remove the schema
  from Exposed schemas before the irreversible drop, but gives the reader no way to CONFIRM the
  dashboard save took effect. This execution did verify it with curl; the reusable template does
  not carry that safeguard forward, which is the one place it matters most.
Task 5: minor (accepted): Release sweep verified on iOS only. Reviewer judged it immaterial —
  sweepOrphans is platform-agnostic Foundation code with no #if os() branching, and macOS builds
  clean on the current tree. I accept that reasoning.
Task 5: complete (commits ac5687e..ce050ba, 1 template minor carried to the final review)

FINAL WHOLE-BRANCH REVIEW (opus, diff c2ae91d..ce050ba): Ready to merge WITH FIXES.
  0 Critical. 5 Important, 6 Minor. Verified the end state independently — pg_namespace empty of
  f_%, profiles 200 with 4 rows, security advisors show only the 4 pre-existing core findings.
  Important 1: sweepOrphans DESTROYS AN INSTALLED FEATURE'S DATA when an id contains `.` or `/`.
    Reviewer proved it with its own swiftc harness (dotted id → key parsed as a different id and
    deleted every launch; slashed id → whole subtree removed). Real bug in shipping core code.
  Important 2: nothing validates id charset or uniqueness, though id is simultaneously schema
    name, directory name, defaults prefix and ForEach identity. Uppercase fails especially
    confusingly — Postgres folds unquoted identifiers, .schema() does not.
  Important 3: makeRoot is documented as called on push; NavigationLink(destination:) builds it
    eagerly per visible tile.
  Important 4: no install-side template, so the SQL future features copy is the executed plan —
    which carries deferred findings 3 (anon grants) and 4 (missing updated_at trigger).
  Important 5: CLAUDE.md still describes a profile-only app; nothing tells the next session this
    is now a plugin shell.
  Deferred triage: 1 carry (test accounts, no PII, no real users); 2 fix (one line, core-wide);
    3+4 fix inside the install template; 5 carry but make defaultsKey the mandated path.

Ruling: fix Important 1, 2, 4, 5, Minor 6 and 11 in one wave, plus Important 3 and Minor 9 as
  documentation-only fixes rather than structural ones.
  — Important 3: I am fixing the comment, not moving Home to navigationDestination(for:). With an
    empty registry the eager construction is unobservable, and restructuring navigation at the end
    of a branch with no test target risks more than it buys. The trap the reviewer fears comes
    from the comment being wrong, and that is what I am correcting. Cost if wrong: a future author
    with many features pays eager init until someone moves to navigationDestination.
  — Minor 9: documenting the sandbox dependency rather than appending the bundle id to the root.
    Changing the root path would strand the Features directory on every existing install, which is
    a worse outcome than the risk it removes. Cost if wrong: someone disabling the macOS sandbox
    for debugging gets a sweep pointed at a shared directory, now at least warned in the code.
  — Minors 7, 8, 10 and deferred 1 carried, not fixed.
Final fix wave: dispatched (opus) — FIX_BASE ce050ba


