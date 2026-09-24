# Client-to-Server Remote Audit (Phase P1-A)

- **Date:** 2026-09-24
- **Auditor:** Automated Hardening Agent
- **Target Repository:** `GAME-BOBLOX`
- **Scope:** Server-side listeners for RemoteEvents and RemoteFunctions across `ServerScriptService`.

---

## 1. Remote Actions Audit Matrix

| Service File | Remote Object | Action / Method | Input Types | Ownership / Auth Check | Location / Spatial Check | Rate Limit / Cooldown | Invariant Status | Test Status |
|---|---|---|---|---|---|---|---|---|
| `BaseUpgradeService.luau` | `UpgradeRemote` (RE) | `"UpgradeTreadmill"` | `action: string` | Server verifies `BaseService.IsOwner(player, base)` and player base data | Distance to `base.BaseFloor <= 60` studs | 0.5s per-player cooldown (`UPGRADE_COOLDOWN`) | Server-authoritative money & level mutation | NOT TESTED |
| `BaseUpgradeService.luau` | `UpgradeRemote` (RE) | `"UpgradeBase"` / `"UpgradePedestal"` | `action: string` | Server verifies `BaseService.IsOwner(player, base)` and player base data | Distance to `base.BaseFloor <= 60` studs | 0.5s per-player cooldown (`UPGRADE_COOLDOWN`) | Server-authoritative slot & cost deduction | NOT TESTED |
| `BatCombatService.luau` | `GetBatShopInfo` (RF) | `OnServerInvoke` | None | Returns caller's own money, equipped bat, and owned bats | None (read-only query) | None | Safe projection, no private data exposed | NOT TESTED |
| `BatCombatService.luau` | `BatRemote` (RE) | `"BuyBat"` | `batId: string` | Verifies `DataService.OwnsBat`, atomic `DataService.SubMoney` | None (shop purchase) | Debounce via server money balance | Idempotent ownership check | NOT TESTED |
| `BatCombatService.luau` | `BatRemote` (RE) | `"EquipBat"` | `batId: string` | Verifies `DataService.OwnsBat(player, batId)` from server data | None (equipment) | None | Cannot equip unowned bat | NOT TESTED |
| `BatCombatService.luau` | `BatRemote` (RE) | `"SwingBat"` | None | Verifies character, live humanoid, tool equipped with valid BatId | `IsInStealZone(hrp.Position)` | Server-enforced swing cooldown (`batConfig.Cooldown - 0.05`) | Server-side raycast / hitbox knockback | NOT TESTED |
| `HatchService.luau` | `HatchRemote` (RE) | `"ClaimHatch"` | `eggModel: Instance` (Model) | Server verifies `eggModel.Parent == base.IncubatingEggs` and `base.OwnerUserId == player.UserId` | Character `HRP` within 24 studs of `EggCore` | Lock flag `IsClaiming` | Atomic pet grant & egg destruction | PASS (Simulation in `tests/test_hatch_ownership.py`) |
| `IndexRewardService.luau` | `IndexRewardRemote` (RE) | `"RequestSync"` | None | Syncs discovered pet set to caller only | None | None | Safe server-to-client replication | NOT TESTED |
| `IndexRewardService.luau` | `IndexRewardRemote` (RE) | `"ClaimZoneBat"` | `zoneId: number` | Server checks `DiscoveredPets` contains all 3 zone pet IDs | None | Server checks `DataService.OwnsBat` before granting | Idempotent (once granted, cannot re-claim) | NOT TESTED |
| `IndexRewardService.luau` | `IndexRewardRemote` (RE) | `"EquipOwnedBat"` | `batId: string` | Verifies `DataService.OwnsBat(player, batId)` | None | None | Re-verifies server ownership | NOT TESTED |
| `MarketplaceServiceHandler.luau` | `MonetizationRemote` (RE) | `"PromptGamepass"` | `passKey: string` | Verified against `MonetizationConfig.GAMEPASSES` | None | In-game prompt dispatch | Studio simulation gated by `RunService:IsStudio()` | NOT TESTED |
| `MarketplaceServiceHandler.luau` | `MonetizationRemote` (RE) | `"PromptProduct"` | `prodId: number` | Verified against `MonetizationConfig.PRODUCTS` | None | In-game prompt dispatch | Studio simulation gated by `RunService:IsStudio()` | NOT TESTED |
| `PetFusionService.luau` | `FuseEvent` (RE) | `"FusePet"` | `petName: string, targetTier: string` | Server scans player's server-stored `pData.Pets` for 3 matching instances & checks cash | Distance to Anvil `<= 35` studs | Server money deduction & pet removal lock | Atomic removal in descending index order | NOT TESTED |
| `PetFusionService.luau` | `FuseEvent` (RE) | `"AutoFuse"` | None | Server scans player's server-stored `pData.Pets` for any 3 matching triplets | Distance to Anvil `<= 35` studs | Server money deduction & pet removal lock | Atomic auto-fusion batch | NOT TESTED |
| `RetentionService.luau` | `GetRetentionData` (RF) | `OnServerInvoke` | None | Returns safe view of caller's daily streak, quest progress, and index | None | None | Read-only projection | NOT TESTED |
| `RetentionService.luau` | `RetentionRemote` (RE) | `"ClaimDailyReward"` | None | Server evaluates `LastDailyClaimTime` (>= 23h elapsed) | None | 23h time interval checked via `os.time()` | Streak reward granted with profile save | NOT TESTED |
| `RetentionService.luau` | `RetentionRemote` (RE) | `"ClaimQuestReward"` | `questId: string` | Server validates `QuestProgress[questId] >= TargetCount` and `not QuestClaimed[questId]` | None | Daily reset validation | Idempotent (marked claimed in profile) | NOT TESTED |
| `RetentionService.luau` | `RetentionRemote` (RE) | `"CompleteTutorial"` | None | Modifies caller's own profile attribute | None | None | Permanent flag `TutorialDone = true` | NOT TESTED |
| `StealZoneService.luau` | `StealZoneRemote` (RE) | `"ExitTreadmill"` | None | Verifies caller is on treadmill via server controller | None | None | Resets player state and dismounts | NOT TESTED |
| `StealZoneService.luau` | `StealZoneRemote` (RE) | `"RequestDrop"` | None | Verifies `carryingPlayers[player]` exists and character is alive | Not allowed in Safe Zone (`hrp.Position.Z > -5`) | 1.0s debounce (`dropCooldowns`) | Drops egg model in battlefield | NOT TESTED |
| `TrailShopService.luau` | `TrailShopRemote` (RE) | `"EquipTrail"` | `trailId: string` | Server validates `pData.SpeedPoints >= trailInfo.UnlockPoints` | Character `HRP` must exist | Cosmetic equip | Server-authoritative SpeedPoints check | NOT TESTED |

---

## 2. Security Invariants & Audit Recommendations

1. **Allow-listing:** All RemoteEvents strictly compare `action` against known string literals; unrecognized strings immediately return/no-op.
2. **Type Checking:** All action arguments are explicitly type-checked (`typeof(arg) == "string"`, `typeof(arg) == "number"`, `typeof(arg) == "Instance"`).
3. **Spatial Validation:**
   - Base upgrades are bound to `dist <= 60` studs from the player's own `BaseFloor`.
   - Hatch claims require `dist <= 24` studs from `EggCore`.
   - Fusion anvil actions require `dist <= 35` studs from the Anvil world position.
   - Steal zone actions verify battlefield boundary coordinates (`Z > -5`).
4. **Rate Limiting:** Combat swings, voluntary egg drops, base upgrades, and daily claims enforce server-side cooldown timers.
5. **Idempotency:** Developer-product receipts and quest rewards enforce permanent durable completion markers before or during persistence.
