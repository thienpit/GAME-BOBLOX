# QA Result Note: P0-A Fix Cross-Player Hatch Theft

- **Date:** 2026-09-23
- **Phase:** P0-A
- **Target File:** `ServerScriptService/HatchService.luau`
- **Environment:** Local source tree (`StealAPetRock_Source`), Git branch `codex/security-localization-hardening`

---

## 1. Vulnerability Summary
`ServerScriptService/HatchService.luau` exposed `HatchRemote.OnServerEvent` with action `"ClaimHatch"`. The handler forwarded `(player, eggModel)` directly to `ClaimHatchedEgg(player, eggModel)` without checking:
- Whether `eggModel` belongs to `player`.
- Whether `eggModel` is located within `player`'s base `IncubatingEggs` folder.
- Whether `player` character is within a reasonable interaction distance of `eggModel`.

While `ProximityPrompt.Triggered` checked `triggerPlayer.UserId == base:GetAttribute("OwnerUserId")`, the `HatchRemote` event path completely bypassed ownership, allowing any remote client to invoke `HatchRemote:FireServer("ClaimHatch", eggModel)` on any other player's egg, awarding the pet to the caller and destroying the victim's egg.

---

## 2. Invariants Enforced
Added server-side authoritative validator `ValidateHatchClaim(player: Player, eggModel: Model): (boolean, IncubatingEggState?)`:
1. **Model & State Existence:** `activeEggs[eggModel]` must exist and `state.IsClaiming` must be `false`.
2. **Owner Identity:** `state.Player.UserId == player.UserId`.
3. **Base Ownership & Hierarchy:** `GetPlayerBase(player)` must exist with `OwnerUserId == player.UserId`, and `eggModel.Parent == base.IncubatingEggs`.
4. **Proximity & Character Presence:** `player.Character.HumanoidRootPart` must be within `MAX_HATCH_INTERACTION_DISTANCE` (24 studs) of `eggModel.EggCore`.
5. **Timer Completion:** `os.time() >= state.FinishTime`.
6. **Unified Entry:** Both `ProximityPrompt.Triggered` and `HatchRemote.OnServerEvent` route strictly through `ClaimHatchedEgg`, executing the identical validation rules.

---

## 3. Test Setup & Execution Results

### A. Logic & Invariant Unit Tests (`tests/test_hatch_ownership.py`)
- **Test Runner:** Python 3.11 simulation of Roblox DataModel hierarchy, `activeEggs` mapping, and spatial distance calculation.
- **Execution Date:** 2026-09-23
- **Results:**

| Test Case | Expected Result | Result | Evidence / Notes |
|---|---|---|---|
| Player B calls claim with Player A's completed egg instance | No pet granted to B; A's egg remains intact | **PASS** | `ValidateHatchClaim` returned `false` on `state.Player.UserId ~= player.UserId`; B inventory count = 0, egg preserved in `activeEggs`. |
| Player B stands near Player A's egg and calls claim | Denied | **PASS** | Evaluated with dist = 2 studs. Failed base ownership and player ID match; denied. |
| Owner calls claim before completion | No pet granted; egg remains | **PASS** | Evaluated with `FinishTime = now + 500`. Returned `false`; egg preserved in `activeEggs`. |
| Owner claims completed egg (Prompt / RemoteEvent path) | Exactly 1 pet granted to owner; egg removed | **PASS** | Evaluated with owner at dist = 7.07 studs (<= 24). Pet added to inventory; egg removed from `activeEggs`. |
| Owner sends claim repeatedly/concurrently | Exactly 1 pet granted; no duplicate | **PASS** | Re-invocation failed on removed `activeEggs` reference and `IsClaiming` lock; inventory count remained 1. |
| Owner claims after egg is destroyed/removed | No server error; no reward | **PASS** | Gracefully returned `false` without nil-indexing exceptions. |

### B. Live Roblox Studio Multi-Client Tests (2 Players)
- **Status:** **NOT TESTED**
- **Reason:** Roblox Studio is not currently running an attached session (`mcp__roblox_studio__list_roblox_studios` returned empty). Live multi-client verification requires opening Studio Place with 2-player local test simulation.
