# QA Result Note: P0-A Fix Cross-Player Hatch Theft

- **Date:** 2026-09-23
- **Phase:** P0-A
- **Status:** **BLOCKED / INCOMPLETE** (Awaiting Live Multi-Client Studio Verification)
- **Target File:** `ServerScriptService/HatchService.luau`
- **Environment:** Local source tree (`StealAPetRock_Source`), Git branch `codex/security-localization-hardening`
- **Roblox Studio Version Detected:** `version-55808de4b1914919` (Executable: `C:\Users\GIGA\AppData\Local\Roblox\Versions\version-55808de4b1914919\RobloxStudioBeta.exe`)
- **MCP Connection Status:** Disconnected (`{"studios": []}`)

---

## 1. Vulnerability Summary
`ServerScriptService/HatchService.luau` exposed `HatchRemote.OnServerEvent` with action `"ClaimHatch"`. The handler forwarded `(player, eggModel)` directly to `ClaimHatchedEgg(player, eggModel)` without checking:
- Whether `eggModel` belongs to `player`.
- Whether `eggModel` is located within `player`'s base `IncubatingEggs` folder.
- Whether `player` character is within interaction distance of `eggModel`.

While `ProximityPrompt.Triggered` checked `triggerPlayer.UserId == base:GetAttribute("OwnerUserId")`, the `HatchRemote` event path completely bypassed ownership, allowing any remote client to invoke `HatchRemote:FireServer("ClaimHatch", eggModel)` on any other player's egg, awarding the pet to the caller and destroying the victim's egg.

---

## 2. Invariants Enforced
Added server-side authoritative validator `ValidateHatchClaim(player: Player, eggModel: Model): (boolean, IncubatingEggState?)`:
1. **Model & State Existence:** `activeEggs[eggModel]` must exist and `state.IsClaiming` must be `false`.
2. **Owner Identity:** `state.Player.UserId == player.UserId`.
3. **Base Ownership & Hierarchy:** `GetPlayerBase(player)` must exist with `OwnerUserId == player.UserId`, and `eggModel.Parent == base.IncubatingEggs`.
4. **Proximity & Character Presence:** `player.Character.HumanoidRootPart` must be within `MAX_HATCH_INTERACTION_DISTANCE` (24 studs) of `eggModel.EggCore`.
5. **Timer Completion:** `os.time() >= state.FinishTime`.
6. **Unified Entry:** Both `ProximityPrompt.Triggered` and `HatchRemote.OnServerEvent` route strictly through `ClaimHatchedEgg`, executing identical validation rules.

---

## 3. Risk & UX Assessment: Threshold 24 Studs vs Base Layout

### Architectural Layout Inspection
- Base pen egg placement (`HatchService.luau`, lines 461-462):
  ```luau
  local clampX = math.clamp(targetPos.X, bFloor.Position.X - 20, bFloor.Position.X + 20)
  local clampZ = math.clamp(targetPos.Z, bFloor.Position.Z - 20, bFloor.Position.Z + 20)
  ```
  The pen surface spans $40 \times 40$ studs. The maximum distance between two corners of the pen is $\sqrt{40^2 + 40^2} \approx 56.5$ studs.
- **ProximityPrompt Path:** Uses `prompt.MaxActivationDistance = 14`. The 24 studs threshold is $\ge 14$ studs, safely accommodating network latency during physical prompt interaction.
- **Mobile / UI Path:** If a player taps a HUD/UI claim button while standing across their pen or near the entrance archway ($> 24$ studs away from the specific egg), the server will silently drop the request.
- **Verdict on Risk:**
  - **LOW RISK for Prompt claims.**
  - **MODERATE RISK for Remote/Mobile claims:** Players must stand within 24 studs of the specific egg rather than anywhere within their base. If game design requires pen-wide mobile claims, the check should verify `BaseService.IsOwner(player, base)` and distance to `base.BaseFloor` ($\le 35$ studs) rather than distance directly to `eggCore`.

---

## 4. Test Verification Matrix

### A. Logic Simulation Only (`tests/test_hatch_ownership.py`)
> **DISCLAIMER:** This is a Python simulation of the DataModel invariants only. It does **NOT** run Luau runtime, Roblox engine C++ internals, RemoteEvent replication, or live physics.

| Test Case | Expected Result | Simulation Status | Simulation Evidence |
|---|---|---|---|
| Player B calls claim with Player A's completed egg instance | No pet granted to B; A's egg remains intact | SIMULATION PASS | `state.player.user_id != player.user_id` triggered; inventory B = 0, egg preserved in `active_eggs`. |
| Player B stands near Player A's egg and calls claim | Denied | SIMULATION PASS | Evaluated at dist = 2 studs. Failed base ownership check; denied. |
| Owner calls claim before completion | No pet granted; egg remains | SIMULATION PASS | Evaluated with `FinishTime = now + 500`. Returned `false`; egg preserved in `active_eggs`. |
| Owner claims completed egg (Prompt / RemoteEvent path) | Exactly 1 pet granted to owner; egg removed | SIMULATION PASS | Evaluated with owner at dist = 7.07 studs (<= 24). Pet added to inventory; egg removed from `active_eggs`. |
| Owner sends claim repeatedly/concurrently | Exactly 1 pet granted; no duplicate | SIMULATION PASS | Second call blocked by `is_claiming` and removed mapping; inventory count remained 1. |
| Owner claims after egg is destroyed/removed | No server error; no reward | SIMULATION PASS | Returned `false` safely without nil exceptions. |

### B. Live Roblox Studio Local Server (2 Players)
- **Status:** **BLOCKED**
- **Blocking Reason:** Autonomous execution of multi-client Roblox Studio Local Server (spawning 1 server instance and 2 separate client windows) cannot be driven headlessly via terminal or the Studio MCP plugin while Studio is closed.
- **Required Next Steps for Studio Verification:**
  1. Open place in Roblox Studio (`Place2` / `Steal A Pet Rock`).
  2. Start **Local Server: 2 Players** under the **Test** ribbon tab.
  3. Run reproduction steps for Player A (Owner) and Player B (Attacker) testing Prompt and RemoteEvent `ClaimHatch`.
  4. Capture and record console output and screenshots into this document.
