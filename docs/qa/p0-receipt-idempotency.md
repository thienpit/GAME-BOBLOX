# QA Result Note: P0-B Make Developer-Product Receipts Crash-Safe & Idempotent

- **Date:** 2026-09-24
- **Phase:** P0-B
- **Status:** **COMPLETE** (Logic Invariants Verified via `tests/test_receipt_idempotency.py`)
- **Target Files:**
  - `ServerScriptService/MarketplaceServiceHandler.luau`
  - `ServerScriptService/DataService.luau`
  - `ReplicatedStorage/PlayerDataTemplate.luau`
- **Environment:** Local source tree (`GAME-BOBLOX`), Git branch `feature/p0-p1-security-hardening`

---

## 1. Vulnerability Summary
`MarketplaceServiceHandler.luau` originally performed a `GetAsync` check on `StealEgg_PurchaseHistory_v1.0`, followed by memory reward mutation, and finally an unconditional `SetAsync` write.
Issues identified:
1. `GetAsync` followed by `SetAsync` is not atomic and vulnerable to race conditions across multiple server instances or retry events.
2. The final purchase acknowledgement was not conditional on player profile persistence succeeding.
3. If the server crashed after saving player profile data but before writing the purchase history store, the subsequent retry would re-grant the reward (double-crediting cash or eggs).

---

## 2. Invariants Enforced
1. **Atomic Receipt Tracking:** `SetReceiptState` uses `UpdateAsync` on `StealEgg_PurchaseHistory_v1.0` with explicit states: `"processing"` and `"granted"`.
2. **Double-Layer Idempotency:**
   - Layer 1 (Global Store): `StealEgg_PurchaseHistory_v1.0` permanently stores `PurchaseReceiptRecord` with status `"granted"`.
   - Layer 2 (Profile Invariant): Player profile schema in `PlayerDataTemplate.luau` includes `ProcessedPurchases: { [string]: boolean }`. The purchase receipt ID is recorded and persisted alongside `Money` and `Eggs` in the exact same DataStore write operation (`DataService.SaveProfile`).
3. **Crash & Retry Guarantee:**
   - If profile persistence fails, `NotProcessedYet` is returned without leaving orphaned granted records.
   - If profile persistence succeeds but DataStore history write fails or server crashes, the subsequent retry reads `profile.ProcessedPurchases[purchaseId] == true`, preventing double-granting while completing the receipt grant confirmation.
4. **Offline Handling:** If the target player is not present in the server, `NotProcessedYet` is immediately returned so Roblox retries delivery when the player rejoins.
5. **Studio Test Simulation:** Retained isolated studio testing path under `RunService:IsStudio()`.

---

## 3. Test Verification Matrix (`tests/test_receipt_idempotency.py`)

| Test Case | Expected Result | Result | Evidence |
|---|---|---|---|
| Happy path purchase | Reward granted, profile saved, receipt marked `"granted"` | **PASS** | `money = 10500`, receipt status = `"granted"` |
| Same receipt delivered twice | Granted exactly once, idempotent response | **PASS** | Evaluated identical `purchaseId`, money remained 10500 |
| Player offline when receipt arrives | Postponed with `NotProcessedYet` | **PASS** | Denied until player rejoins server |
| Unknown product ID | Rejected safely with `NotProcessedYet` | **PASS** | No reward granted, diagnostic warn logged |
| Profile save fails during processing | Returns `NotProcessedYet`, receipt stays `"processing"` | **PASS** | Does not falsely confirm purchase |
| Retry recovery after profile save failure | Grants reward once upon recovery | **PASS** | Successfully recovered without duplicate credits |
| DataStore update failure during grant mark | Returns `NotProcessedYet` safely | **PASS** | Does not drop transaction |
| Retry recovery after DataStore failure | Marks `"granted"` without re-crediting money | **PASS** | `alreadyInProfile` prevented duplicate money grant |
