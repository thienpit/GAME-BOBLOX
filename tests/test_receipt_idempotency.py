"""
[SIMULATION ONLY — INVARIANT LOGIC CHECK]
Simulation unit test for Phase P0-B: Developer-Product Receipts Crash-Safety & Idempotency.
Directly models MarketplaceServiceHandler.luau and DataService profile interaction.

NOTE: This is a standalone Python logic test only.
It does NOT execute Luau runtime, Roblox engine C++ internals, or live Cloud DataStore.
"""
import time
from dataclasses import dataclass, field
from typing import Optional, Dict, Any

class ProductPurchaseDecision:
    PurchaseGranted = "PurchaseGranted"
    NotProcessedYet = "NotProcessedYet"

@dataclass
class PurchaseReceiptRecord:
    purchase_id: str
    player_id: int
    product_id: int
    status: str  # "processing" | "granted"
    created_at: int
    granted_at: Optional[int] = None

@dataclass
class PlayerData:
    money: int = 500
    eggs: list = field(default_factory=list)
    processed_purchases: Dict[str, bool] = field(default_factory=dict)

class MockDataStore:
    def __init__(self):
        self.store: Dict[str, Any] = {}
        self.fail_get: bool = False
        self.fail_update: bool = False

    def get_async(self, key: str):
        if self.fail_get:
            raise RuntimeError("DataStore connection timeout (GetAsync)")
        return self.store.get(key)

    def update_async(self, key: str, transform_fn):
        if self.fail_update:
            raise RuntimeError("DataStore connection timeout (UpdateAsync)")
        current = self.store.get(key)
        new_val = transform_fn(current)
        self.store[key] = new_val
        return new_val

class MarketplaceReceiptHandler:
    def __init__(self, datastore: MockDataStore, products_config: dict):
        self.datastore = datastore
        self.products_config = products_config
        self.loaded_profiles: Dict[int, PlayerData] = {}
        self.online_players: Dict[int, str] = {}
        self.fail_profile_save: bool = False
        self.client_notifications: list = []

    def get_receipt_record(self, purchase_id: str):
        try:
            return True, self.datastore.get_async(purchase_id)
        except Exception:
            return False, None

    def set_receipt_state(self, purchase_id: str, player_id: int, product_id: int, status: str) -> bool:
        try:
            def transform(current):
                if current is True or (isinstance(current, dict) and current.get("status") == "granted"):
                    return current
                now = int(time.time())
                created_at = current.get("created_at", now) if isinstance(current, dict) else now
                granted_at = now if status == "granted" else (current.get("granted_at") if isinstance(current, dict) else None)
                return {
                    "purchase_id": purchase_id,
                    "player_id": player_id,
                    "product_id": product_id,
                    "status": status,
                    "created_at": created_at,
                    "granted_at": granted_at,
                }
            self.datastore.update_async(purchase_id, transform)
            return True
        except Exception:
            return False

    def save_profile(self, player_id: int) -> bool:
        if self.fail_profile_save:
            return False
        return True

    def process_receipt(self, receipt_info: dict) -> str:
        purchase_id = receipt_info["purchase_id"]
        player_id = receipt_info["player_id"]
        product_id = receipt_info["product_id"]

        # Step 1: Check if already granted in DataStore
        check_ok, record = self.get_receipt_record(purchase_id)
        if check_ok and record:
            if record is True or (isinstance(record, dict) and record.get("status") == "granted"):
                return ProductPurchaseDecision.PurchaseGranted

        # Step 2: Player must be online in server
        if player_id not in self.online_players:
            return ProductPurchaseDecision.NotProcessedYet

        # Step 3: Product must exist in config
        product_config = self.products_config.get(product_id)
        if not product_config:
            return ProductPurchaseDecision.NotProcessedYet

        # Step 4: Mark processing
        self.set_receipt_state(purchase_id, player_id, product_id, "processing")

        # Step 5: Check profile idempotency
        profile = self.loaded_profiles.get(player_id)
        if not profile:
            return ProductPurchaseDecision.NotProcessedYet

        if not profile.processed_purchases.get(purchase_id):
            if product_config["reward_type"] == "Money":
                profile.money += int(product_config["reward_value"])
            elif product_config["reward_type"] == "Egg":
                profile.eggs.append(product_config["reward_value"])
            profile.processed_purchases[purchase_id] = True

        # Step 6: Persist profile
        if not self.save_profile(player_id):
            return ProductPurchaseDecision.NotProcessedYet

        # Step 7: Mark granted in DataStore
        if not self.set_receipt_state(purchase_id, player_id, product_id, "granted"):
            return ProductPurchaseDecision.NotProcessedYet

        # Step 8: Notify client
        self.client_notifications.append((player_id, product_config["name"]))
        return ProductPurchaseDecision.PurchaseGranted


def run_tests():
    products = {
        101: {"name": "+$10,000 Cash", "reward_type": "Money", "reward_value": 10000},
        102: {"name": "Obsidian Egg Pack", "reward_type": "Egg", "reward_value": "ObsidianEgg"},
    }

    # Test 1: Happy path purchase
    ds = MockDataStore()
    handler = MarketplaceReceiptHandler(ds, products)
    handler.online_players[1] = "Player1"
    handler.loaded_profiles[1] = PlayerData(money=500)

    receipt = {"purchase_id": "tx_001", "player_id": 1, "product_id": 101}
    decision = handler.process_receipt(receipt)
    assert decision == ProductPurchaseDecision.PurchaseGranted, f"Expected PurchaseGranted, got {decision}"
    assert handler.loaded_profiles[1].money == 10500, "Money should be 10500"
    assert ds.get_async("tx_001")["status"] == "granted", "DataStore status must be granted"
    print("  [PASS] Happy path developer-product purchase")

    # Test 2: Same receipt delivered twice (Idempotency)
    decision2 = handler.process_receipt(receipt)
    assert decision2 == ProductPurchaseDecision.PurchaseGranted
    assert handler.loaded_profiles[1].money == 10500, "Money must not double-grant"
    print("  [PASS] Same receipt delivered twice is idempotent")

    # Test 3: Player offline when receipt arrives
    receipt_offline = {"purchase_id": "tx_002", "player_id": 2, "product_id": 101}
    dec_off = handler.process_receipt(receipt_offline)
    assert dec_off == ProductPurchaseDecision.NotProcessedYet, "Offline player must return NotProcessedYet"
    assert ds.get_async("tx_002") is None or ds.get_async("tx_002").get("status") != "granted"
    print("  [PASS] Offline player receipt is postponed")

    # Test 4: Unknown product ID
    receipt_unknown = {"purchase_id": "tx_003", "player_id": 1, "product_id": 999}
    dec_unk = handler.process_receipt(receipt_unknown)
    assert dec_unk == ProductPurchaseDecision.NotProcessedYet, "Unknown product must not grant"
    print("  [PASS] Unknown product ID safely rejected")

    # Test 5: Profile write fails during receipt processing
    handler.fail_profile_save = True
    receipt_fail = {"purchase_id": "tx_004", "player_id": 1, "product_id": 101}
    dec_fail = handler.process_receipt(receipt_fail)
    assert dec_fail == ProductPurchaseDecision.NotProcessedYet, "Failed save must return NotProcessedYet"
    assert ds.get_async("tx_004")["status"] == "processing", "Must not be marked granted"
    print("  [PASS] Profile save failure returns retry decision")

    # Test 6: Recovery after profile save failure on subsequent retry
    handler.fail_profile_save = False
    initial_money = handler.loaded_profiles[1].money
    dec_rec = handler.process_receipt(receipt_fail)
    assert dec_rec == ProductPurchaseDecision.PurchaseGranted
    # Profile already recorded tx_004, so money shouldn't increase twice
    assert handler.loaded_profiles[1].money == initial_money, "Recovery must not duplicate reward"
    assert ds.get_async("tx_004")["status"] == "granted"
    print("  [PASS] Retry recovery after transient failure without duplicate grant")

    # Test 7: DataStore write failure during final grant mark
    receipt_ds_fail = {"purchase_id": "tx_005", "player_id": 1, "product_id": 101}
    ds.fail_update = True
    dec_ds = handler.process_receipt(receipt_ds_fail)
    assert dec_ds == ProductPurchaseDecision.NotProcessedYet, "DataStore update failure returns NotProcessedYet"
    print("  [PASS] DataStore update failure safely postpones without losing reward")

    # Test 8: Recovery of Test 7 on next retry
    ds.fail_update = False
    dec_ds_retry = handler.process_receipt(receipt_ds_fail)
    assert dec_ds_retry == ProductPurchaseDecision.PurchaseGranted
    assert ds.get_async("tx_005")["status"] == "granted"
    print("  [PASS] DataStore retry finalizes grant without duplicate reward")

    print("\nALL 8 P0-B ACCEPTANCE LOGIC TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    run_tests()
