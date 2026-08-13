# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

`null-app` is a **standalone SwiftUI application** and a self-contained git repository. It shares no code, design system, or conventions with any sibling folder under `WROKSPACE/`. The workspace-level `CLAUDE.md` at `/Users/purintae/Documents/WROKSPACE/CLAUDE.md` auto-loads and describes a documents-only workspace with "no build, test, or lint step" — **that does not apply here**. This project builds with Xcode, and the instructions in this file take precedence.

The app is a real profile app backed by Supabase: sign up with a display name only (no password, no email), then your profile and images live on the server.

## Commands

Build for simulator (no code signing required):

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

Build for macOS:

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Clean:

```bash
xcodebuild -scheme null-app clean
```

There is **no test target**. `xcodebuild test` will fail until one is added.

## How to verify changes

With no test target, "it compiles" proves very little — every bug found so far compiled cleanly and would have passed review. Verification means running the real flow against the real backend:

| Layer | How |
|---|---|
| SQL, RLS | `execute_sql` via the Supabase MCP server, against the real database |
| Pure logic | `swiftc` on the real file plus a throwaway harness |
| UI, end-to-end | build → install → launch → screenshot, then compare the screen against the actual row in the database |

**A screen that looks right is not evidence.** Read the row back and compare it to what is displayed. Several bugs presented as a correct-looking screen over wrong server state.

Driving the simulator:

```bash
xcrun simctl install <SIM_UDID> "$(xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2"/null-app.app"}')"
xcrun simctl launch <SIM_UDID> purin.null-app
```

To get a genuine first-run state you need **both** of these — see the Keychain gotcha below:

```bash
xcrun simctl uninstall <SIM_UDID> purin.null-app
xcrun simctl keychain <SIM_UDID> reset
```

## Architecture

Three layers of identity, kept deliberately separate so authentication methods can be added later without touching profile data:

```
auth.users.id     internal identity, immutable, minted by Supabase
public.profiles   public identity — display_name, stable_suffix, bio, image paths
auth.identities   how you prove ownership (today: anonymous device credential only)
```

Swift side, under `null-app/`:

- **`Storage/Backend.swift`** — the only place a `SupabaseClient` is constructed. Everything else goes through `Backend.client`. The publishable key is committed on purpose; it is designed to ship in clients, and RLS is what actually protects data.
- **`Storage/SessionStore.swift`** — owns `State { loading, signedOut, signedIn }`, which decides whether the app root is the sign-up screen or Home. `.signedIn` means **usable**, not merely authenticated: it is withheld until the profile row exists.
- **`Storage/ProfileStore.swift`** — sole owner of profile state, and the only file that talks to the `profiles` table or Storage. Its public surface (`profile`, `refresh()`, `update(_:avatar:cover:)`) is unchanged from when data lived in a local file, so views never learned that a backend appeared.
- **`Storage/RemoteProfile.swift`** — the shape of a `profiles` row, with hand-written `CodingKeys` because the decoder belongs to the library.
- **`Models/Profile.swift`** — the view-facing model plus all name validation. `SignUpView` and `ProfileEditView` both borrow `Profile.isValid`, so there is exactly one set of naming rules.

`profile.json` and the local images directory are **cache only** — the server is the source of truth. `ProfileStore.init` wipes them when there is no session, so a new account on a shared device cannot see the previous owner's profile.

## Backend

Supabase project `yqeqzplufezlnudsxzql` (`null-app`, ap-southeast-1). Apply schema changes with the MCP server's `apply_migration`, never by hand in the dashboard, so the migration history stays the record.

- `public.profiles` — PK **and** FK on `user_id` → `auth.users(id) ON DELETE CASCADE`, so one user has exactly one profile and deleting the user removes it.
- `stable_suffix` — 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no `I O 0 1`), UNIQUE, generated **by the database**. The app must never mint one.
- Storage bucket `profile-images`, publicly readable, writable only inside a folder named after the owner's `user_id`.

RLS is the entire security model. A policy that has not been tested by trying to break it is a policy nobody knows the behaviour of — when adding one, prove it *refuses* the bad case, not just that it permits the good one.

## Project configuration

Facts spread across `project.pbxproj` that shape how you should work:

**Synchronized file groups.** The project uses `PBXFileSystemSynchronizedRootGroup` (`objectVersion = 77`, Xcode 16+). Every file under `null-app/` is picked up automatically. **Create new Swift files with the Write tool directly — never hand-edit `project.pbxproj` to register them.** Editing that file to add sources is both unnecessary and likely to corrupt the project. Note the empty `Models/` directory at the repo *root* is outside the synchronized group and compiles nothing; app code goes in `null-app/Models/`.

**Swift package dependencies are the exception.** `supabase-swift` (up to next major from 2.5.1) is a `XCRemoteSwiftPackageReference`, and the products `Supabase`, `Auth`, `PostgREST`, `Storage`, `Realtime`, `Functions` are linked to the target. Adding a package reference is *not* enough — a product must appear in `packageProductDependencies` or `import Supabase` fails with "unable to resolve module dependency". That linkage is done in Xcode (target → General → Frameworks, Libraries, and Embedded Content), and `grep -c supabase-swift project.pbxproj` will happily pass while the build is still broken.

**One target, four platforms.** A single `null-app` target ships to iOS, iPadOS, macOS, and visionOS (`TARGETED_DEVICE_FAMILY = "1,2,7"`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator"`). There is no per-platform target, so all code is shared. When a layout or API only makes sense on one platform, gate it with `#if os(...)` or size-class checks rather than assuming iPhone. Build both iOS and macOS before calling a change done; macOS catches missing imports that iOS incremental builds miss.

**MainActor by default.** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` are set, while `SWIFT_VERSION = 5.0` keeps language mode 5. Practically: unannotated types and functions are already main-actor-isolated, so UI code needs no `@MainActor` annotation, and work intended to run off the main actor must be explicitly marked (`nonisolated`, or moved into an actor / `Task.detached`).

**No Info.plist file.** `GENERATE_INFOPLIST_FILE = YES`. To add plist keys (usage descriptions, URL schemes, background modes), add `INFOPLIST_KEY_*` build settings rather than creating an `Info.plist`.

**Deployment target 26.5** for both iOS and macOS. Availability checks are unnecessary for anything introduced at or below 26.5 — modern APIs (`@Observable`, SwiftData, the current SwiftUI surface) can be used unconditionally.

**Signing.** `CODE_SIGN_STYLE = Automatic` with no `DEVELOPMENT_TEAM` set. Simulator builds work as-is; building for a physical device requires selecting a team in Xcode first. Bundle identifier is `purin.null-app`.

## Traps that have already cost time

Each of these compiled cleanly and looked correct.

**A partial update must send `null`, not omit the key.** Swift's synthesized `Encodable` uses `encodeIfPresent` for Optionals, so a nil field disappears from the JSON — and PostgREST reads a missing key as "leave this column alone". Clearing a column silently did nothing. Any PATCH payload with optional fields needs a hand-written `encode(to:)`.

**Postgres renders UUIDs lowercase; Swift's `UUID.uuidString` is uppercase.** Storage paths are compared against `auth.uid()::text` as strings, so an unlowercased path can never satisfy the policy and every upload is refused.

**`simctl uninstall` does not sign the user out.** supabase-swift keeps the session in the Keychain, which survives app deletion, so the app relaunches as the previous user. Any "first launch" test without `simctl keychain reset` is testing nothing.

**Storage rows cannot be deleted in SQL.** A `storage.protect_delete()` trigger rejects `delete from storage.objects`. Use the Storage API or the dashboard.

**Auth events arrive before your follow-up work finishes.** `signInAnonymously` publishes to `authStateChanges` the moment the token lands, and SwiftUI re-renders on that event, not when your `async` function returns. If you gate that stream, you own re-publishing the state on *every* exit path, including the throwing one.

**`information_schema` hides cross-schema foreign keys** from the MCP role. Query `pg_constraint` instead, or you will conclude `profiles` has no foreign key.

**The macOS sandbox blames DNS when it blocks the network.** `ENABLE_APP_SANDBOX = YES` is on for this target, so the macOS build reaches the network only if `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` puts `com.apple.security.network.client` into the generated entitlements. Without it every request fails as `NSURLErrorCannotFindHost (-1003)` — surfaced to the user as "A server with the specified hostname could not be found" — while `curl` to the same host from the same Mac succeeds. iOS has no such gate, so the simulator will never show this. Read the shipped entitlements, not the build setting: `codesign -d --entitlements - --xml <path>.app | plutil -convert xml1 -o - -`.

## Design docs

`docs/superpowers/specs/` holds the design decisions and, importantly, the rejected alternatives with reasons. `docs/superpowers/plans/` holds the implementation plans. Read the relevant spec before changing behaviour it covers — several choices that look arbitrary (name-only signup, database-owned suffix, no Recovery Key) are deliberate and argued there.

`.superpowers/sdd/<plan>/progress.md` is the running ledger for a plan: what was done, what was decided, what was found and ruled out. It is untracked, and it is the fastest way to pick up where a previous session stopped.

**Accounts currently have one credential — the device session.** Losing the Keychain loses the account permanently. This is a knowingly accepted limitation; the designed fix (a recovery email linked to the same `user_id`) is deferred and should not be started without asking.
