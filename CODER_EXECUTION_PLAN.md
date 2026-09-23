# Steal A Pet Rock — Coder Execution Plan

## 0. Purpose and operating rules

This document is the single implementation brief for the next hardening pass. Work in the stated order. Do **not** broaden scope, rebalance the economy, replace assets, rename persistent data, or claim test results that were not actually run.

### Non-negotiable rules

1. Make a Git branch before editing. Suggested name: `codex/security-localization-hardening`.
2. Make small, reviewable commits by phase. Do not mix security changes with copy/design changes.
3. Do not delete the existing `QA_BENCHMARK_REPORT*.md` files in this task. Move/organize documentation only in a separate documentation commit.
4. The server is authoritative. A client RemoteEvent is a request, never proof that the player owns an object, may perform an action, or is close enough to an object.
5. Do not rename existing DataStore names, developer product IDs, game pass IDs, serialized data fields, RemoteEvent names, or config IDs unless a separately approved migration is supplied.
6. Do not invent Roblox asset IDs, Marketplace metadata, gameplay evidence, profiling measurements, or playtest outcomes. For every claimed result, record exact reproduction steps and the observed output.
7. If a requirement below conflicts with the currently published game behavior, stop and report the conflict with the relevant code location before changing it.

## 1. QA assessment: what has been useful, and what remains uncovered

The existing QA reports appear useful for gameplay and UX discovery. The code contains implementations consistent with several reported findings:

- Mobile/desktop hatch requests exist through `HatchRemote`.
- Treadmill flow includes carrying-item feedback.
- Night/hatch and retention-related systems exist in the codebase.

However, reports are not a substitute for security or persistence testing. The current source still has a high-severity ownership issue in the mobile hatch RemoteEvent, and payment receipt persistence is not crash-safe enough. Treat existing reports as historical test notes, not proof that the current exported source is production-ready.

## 2. Phase P0-A — Fix cross-player hatch theft

### Risk

`ServerScriptService/HatchService.luau` accepts `HatchRemote:FireServer("ClaimHatch", eggModel)`. Its `ClaimHatchedEgg(player, eggModel)` function checks that an egg is active and ready, but does not currently prove that the requesting player owns that egg/base. The 3D prompt has an owner check; the RemoteEvent path bypasses it.

### Required implementation

1. Add a small server-side validator for a hatch claim, preferably next to `ClaimHatchedEgg`.
2. Validate all of the following before setting `state.IsClaiming`:
   - `activeEggs[eggModel]` exists.
   - `state.Player == player` (use `UserId` comparison if player object identity is not guaranteed by the service design).
   - The egg still belongs to the base returned by `GetPlayerBase(player)`.
   - That base has `OwnerUserId == player.UserId`.
   - The egg is under the expected `IncubatingEggs` hierarchy for that base.
   - The player character has a live `HumanoidRootPart` and is within a defined interaction distance of the egg/core. Reuse a named constant; do not use an unexplained magic number.
   - `os.time() >= state.FinishTime`.
3. Keep the server-side `IsClaiming` lock. Ensure every failure path leaves it unset.
4. Route both `ProximityPrompt.Triggered` and `HatchRemote.OnServerEvent` through the same validator. Do not keep two slightly different authorization rules.
5. Silently ignore invalid client requests or send a generic failure event; do not reveal other players' egg state to the requester.
6. Do not trust client-provided egg names, owner IDs, finish times, positions, or pet-roll information.

### Acceptance tests

Run these in Studio with two test players and record PASS/FAIL:

| Test | Expected result |
|---|---|
| Owner claims their completed egg by prompt | Exactly one pet is granted to owner |
| Owner claims their completed egg by mobile RemoteEvent/UI path | Exactly one pet is granted to owner |
| Player B calls claim with Player A's completed egg instance | No pet, money, quest progress, or UI reveal is granted to B; A's egg remains |
| Player B stands near Player A's egg and calls claim | Same denial |
| Owner calls claim before completion | No pet; egg remains |
| Owner sends claim repeatedly/concurrently | Exactly one pet; no duplicate pet/data entry |
| Owner claims after egg is destroyed/removed | No server error; no reward |

### Deliverable

- Focused code diff.
- A short `docs/qa/p0-hatch-ownership.md` result note containing exact test setup, test date, and PASS/FAIL only. No unverified claims.

## 3. Phase P0-B — Make developer-product receipts crash-safe and idempotent

### Risk

`MarketplaceServiceHandler.luau` currently checks receipt history with `GetAsync`, grants the reward, then writes history with `SetAsync`. This is not an atomic claim operation. The code also does not make final purchase acknowledgement conditional on all required persistence succeeding.

### Required implementation

1. Replace the separate `GetAsync`/`SetAsync` receipt claim with an atomic `UpdateAsync`-based receipt record or an equivalent robust server-side receipt state machine.
2. Define explicit receipt states, e.g. `processing`, `granted`, and enough metadata to diagnose a retry safely. Do not store unnecessary player data.
3. A receipt must only return `PurchaseGranted` after:
   - the product ID is recognised;
   - the player reward mutation succeeds;
   - the profile persistence required by the design succeeds; and
   - the receipt is durably marked as granted.
4. If any step fails, return `NotProcessedYet` without creating a duplicate reward on retry.
5. Make the ordering explicit and document why a crash/retry cannot either lose a paid reward or grant it twice. If this cannot be made fully atomic with the current profile format, state that clearly and propose the smallest safe schema change before implementing it.
6. Preserve current Studio purchase simulation only as a test-only code path. It must remain gated by `RunService:IsStudio()` and must not create production-only receipt state.
7. Confirm no other script assigns `MarketplaceService.ProcessReceipt`; Roblox permits only one handler.

### Acceptance tests

| Test | Expected result |
|---|---|
| Same receipt delivered twice | Reward is present exactly once |
| Profile write fails during a receipt | Handler returns retry decision; no false success message |
| Receipt history write fails | Handler returns retry decision; no false success message |
| Player leaves before receipt is handled | Handler returns retry decision and grants on a later valid retry |
| Unknown product ID | No reward; retry/diagnostic path is safe |
| Studio simulated product request | Test reward works only in Studio; production path still calls Roblox prompt |

### Deliverable

- Focused code diff.
- `docs/qa/p0-receipt-idempotency.md` with the actual test evidence and any limitations.

## 4. Phase P1-A — Audit every client-to-server action

### Scope

Audit these server entry points:

- `BaseUpgradeService.luau` — `UpgradeRemote`
- `BatCombatService.luau` — `BatRemote`
- `HatchService.luau` — `HatchRemote`
- `IndexRewardService.luau` — `IndexRewardRemote`
- `MarketplaceServiceHandler.luau` — `MonetizationRemote`
- `PetFusionService.luau` — `FuseEvent`
- `RetentionService.luau` — `RetentionRemote` and `GetRetentionData`
- `StealZoneService.luau` — `StealZoneRemote`
- `TrailShopService.luau` — `TrailShopRemote`

### Required checklist for each action

1. Allow-list action names. Unknown actions must no-op safely.
2. Type-check every argument before use.
3. Validate ownership from server data, not UI/client state.
4. Validate world state and distance where the action is spatial.
5. Add action-specific rate limits where repeat calls could create load, money, rewards, or combat effects.
6. Ensure every reward operation is idempotent or protected by server state.
7. Avoid exposing private player data through RemoteFunctions.
8. Do not add broad `pcall` blocks that hide authorization failures.

### Deliverable

Create `docs/REMOTE_AUDIT.md` with one row per action: file, action name, input types, ownership check, location check, cooldown, and test status. Mark unknown/unverified items as `NOT TESTED`, never PASS.

## 5. Phase P1-B — English-only player-facing localization

### Objective

The released game is English-only. Runtime player-facing text must not contain Vietnamese. Internal comments/logs can be migrated separately, but do not allow Vietnamese text to leak into UI.

### Required implementation

1. Add `ReplicatedStorage/Shared/Localization/en.luau` (or a similarly named single English catalog) with stable semantic keys.
2. Move player-facing literals from config/UI into this catalog or store canonical English names in the relevant config.
3. Preserve stable data IDs such as `trail_dust` and `wooden_bat`; change display values only.
4. Replace at minimum:
   - Trail names in `TrailConfig.luau`.
   - Bat `ZoneRewardText` values in `BatConfig.luau`.
   - Any Vietnamese `Name`, `Title`, `Text`, `Description`, `ActionText`, `ObjectText`, notification, or quest string reachable by a player.
5. Suggested translations:
   - `Bụi Tân Thủ` → `Rookie Dust`
   - `Vệt Điện Xanh` → `Blue Lightning Trail`
   - `Ngọn Lửa Hỏa Ngục` → `Inferno Flame Trail`
   - `Bóng Tối Hư Không` → `Void Shadow Trail`
   - `Bụi Sao Tinh Tú` → `Stardust Trail`
   - `Lượng Tử Cầu Vồng` → `Quantum Rainbow Trail`
   - Bat requirements should use the pattern `Collect all 3 pets from <Zone>.`
6. Do not translate data keys, pet IDs, attribute names, RemoteEvent names, or DataStore fields as part of localization.
7. Add a static scan command to the documentation/CI that fails or reports when Vietnamese diacritics occur in known player-facing source paths. It may allow an explicit comment/log exemption until the internal cleanup phase.

### Acceptance tests

- Open every shop, trail UI, bat/index UI, hatch UI, HUD, quest/daily UI, upgrades, and mobile hatch UI.
- Capture screenshots or a UI-text inventory showing English-only output.
- Search the player-facing source/config catalog for Vietnamese diacritics; document every deliberate exemption.

## 6. Phase P1-C — Remove fragile cross-service `_G` coupling

### Current examples

The code publishes/consumes `_G.SpawnRoamingPetInPen`, `_G.RecalculateBaseIncome`, `_G.HatchPlaceEgg`, `_G.ExitTreadmill`, plus client UI globals such as `_G.OpenTrailShop`.

### Required implementation

1. Introduce narrow ModuleScript APIs or BindableEvents for each cross-service capability.
2. Each API must have one owner, typed inputs/outputs, and an initialization contract.
3. Migrate one dependency group at a time:
   - Hatch/PetFusion/Base income.
   - Treadmill/Steal Zone.
   - Client navigation between retention, trail shop, index, and Robux shop.
4. Remove the corresponding `_G` export only after every call site is migrated and tested.
5. Do not rewrite gameplay behavior as part of this refactor.

### Acceptance tests

- Fresh server start has no nil/global initialization errors.
- All migrated flows work after respawn and after late-loading UI.
- Search confirms migrated global names have no remaining references.

## 7. Phase P2 — Reliability and maintainability

### Data and migration

1. Add a `SchemaVersion` to player data only with a backward-compatible migration plan.
2. Validate nested profile structures, not only missing top-level default fields.
3. Retain existing `StealEgg_PlayerProfile_v1.0` and purchase-history store names until a separate migration is approved. They are legacy names, not permission to reset live data.
4. Test: rejoin, rapid server transition, failed save, shutdown save, and schema upgrade from a representative old profile.

### Module boundaries

Split only after P0/P1 passes:

- `RockGameManager`: world bootstrap, treadmill state, round/night event.
- `HatchService`: egg lifecycle, ownership, pet-roll/award, pen presentation.
- `StealZoneService`: spawning, carry/drop, safe-zone transitions.

Keep behavior unchanged while splitting. Add a smoke test after each extraction.

### Performance

Profile in Roblox Studio before optimizing. Record server memory, heartbeat/script activity, instance count, and network traffic at 1, 10, and 30 players. Review the many independent `while true` loops only after measurements identify a hotspot.

## 8. Definition of done and handoff format

For each completed phase, the coder must provide:

1. Commit hash and concise change summary.
2. Files changed.
3. Security/reliability invariant enforced.
4. Exact test cases run, player count, result, and known untested cases.
5. Screenshots/log excerpts only when actually captured.
6. Any migration, rollback, or publish risk.

Do not report a phase complete if an acceptance test is missing. Use `BLOCKED` with the exact missing capability or decision instead.

## 9. Prompt to send to the coding agent

> You are hardening the Roblox Luau project `StealAPetRock_Source`. Follow `CODER_EXECUTION_PLAN.md` exactly, starting with Phase P0-A only. Do not change scope. Before editing, summarize the current vulnerable flow with exact file/function references. Implement the smallest secure fix, run every P0-A acceptance test that is possible in the available environment, and report actual results as PASS, FAIL, or NOT TESTED. Do not claim a playtest, asset verification, performance measurement, or purchase behavior you did not personally execute. Do not rename DataStores, serialized fields, product IDs, RemoteEvents, config IDs, or rebalance the game. Stop after P0-A and provide a review-ready diff plus the required QA note; wait for approval before starting P0-B.
