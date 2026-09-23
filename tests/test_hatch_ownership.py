"""
Simulation unit test for Phase P0-A: Hatch Claim Ownership & Security Invariants.
Directly models the Luau ValidateHatchClaim and ClaimHatchedEgg functions from HatchService.luau.
"""
import time
import math
from dataclasses import dataclass, field
from typing import Optional, Dict, Any

MAX_HATCH_INTERACTION_DISTANCE = 24

@dataclass
class Vector3:
    x: float
    y: float
    z: float

    def distance_to(self, other: 'Vector3') -> float:
        return math.sqrt((self.x - other.x)**2 + (self.y - other.y)**2 + (self.z - other.z)**2)

@dataclass(eq=False)
class Instance:
    name: str
    parent: Optional['Instance'] = None
    attributes: Dict[str, Any] = field(default_factory=dict)
    children: Dict[str, 'Instance'] = field(default_factory=dict)

    def is_a(self, class_name: str) -> bool:
        return class_name == "Model"

    def get_attribute(self, key: str, default=None):
        return self.attributes.get(key, default)

    def set_attribute(self, key: str, value: Any):
        self.attributes[key] = value

    def find_first_child(self, name: str) -> Optional['Instance']:
        return self.children.get(name)

    def add_child(self, child: 'Instance'):
        child.parent = self
        self.children[child.name] = child

@dataclass(eq=False)
class Part(Instance):
    position: Vector3 = field(default_factory=lambda: Vector3(0, 0, 0))

@dataclass(eq=False)
class Model(Instance):
    primary_part: Optional[Part] = None

@dataclass(eq=False)
class Player:
    user_id: int
    name: str
    character: Optional[Model] = None

@dataclass(eq=False)
class IncubatingEggState:
    egg_id: str
    player: Player
    egg_name: str
    finish_time: int
    egg_model: Model
    is_claiming: bool = False

# World State Simulation
class GameWorld:
    def __init__(self):
        self.active_eggs: Dict[Model, IncubatingEggState] = {}
        self.player_bases: Dict[int, Model] = {}
        self.player_inventory: Dict[int, list] = {}

    def get_player_base(self, player: Player) -> Optional[Model]:
        return self.player_bases.get(player.user_id)

    def validate_hatch_claim(self, player: Player, egg_model: Model) -> tuple[bool, Optional[IncubatingEggState]]:
        if not player or not egg_model or not isinstance(egg_model, Model):
            return False, None

        state = self.active_eggs.get(egg_model)
        if not state or state.is_claiming:
            return False, None

        # 1. Owner identity check
        if not state.player or state.player.user_id != player.user_id:
            return False, None

        # 2. Base ownership & hierarchy check
        base = self.get_player_base(player)
        if not base:
            return False, None

        owner_user_id = base.get_attribute("OwnerUserId")
        if owner_user_id != player.user_id:
            return False, None

        egg_folder = base.find_first_child("IncubatingEggs")
        if not egg_folder or egg_model.parent != egg_folder:
            return False, None

        # 3. Character presence and proximity check
        char = player.character
        if not char:
            return False, None

        hrp = char.find_first_child("HumanoidRootPart")
        egg_core = egg_model.primary_part or egg_model.find_first_child("EggCore")
        if not hrp or not egg_core:
            return False, None

        distance = hrp.position.distance_to(egg_core.position)
        if distance > MAX_HATCH_INTERACTION_DISTANCE:
            return False, None

        # 4. Incubation timer completion check
        if int(time.time()) < state.finish_time:
            return False, None

        return True, state

    def claim_hatched_egg(self, player: Player, egg_model: Model) -> bool:
        is_valid, state = self.validate_hatch_claim(player, egg_model)
        if not is_valid or not state:
            return False

        state.is_claiming = True

        # Simulate pet roll & grant
        rolled_pet = {"Name": "Pet Rock", "Egg": state.egg_name}
        self.player_inventory.setdefault(player.user_id, []).append(rolled_pet)

        # Cleanup egg
        del self.active_eggs[egg_model]
        if egg_model.parent and egg_model.name in egg_model.parent.children:
            del egg_model.parent.children[egg_model.name]
        egg_model.parent = None

        return True

def run_acceptance_tests():
    now = int(time.time())
    world = GameWorld()

    # Setup Player A (Owner)
    player_a = Player(user_id=1001, name="PlayerA")
    char_a = Model(name="CharA")
    hrp_a = Part(name="HumanoidRootPart", position=Vector3(0, 0, 0))
    char_a.add_child(hrp_a)
    player_a.character = char_a

    # Base A setup
    base_a = Model(name="Base_1")
    base_a.set_attribute("OwnerUserId", 1001)
    egg_folder_a = Instance(name="IncubatingEggs")
    base_a.add_child(egg_folder_a)
    world.player_bases[1001] = base_a

    # Setup Player B (Attacker / Other Player)
    player_b = Player(user_id=2002, name="PlayerB")
    char_b = Model(name="CharB")
    hrp_b = Part(name="HumanoidRootPart", position=Vector3(100, 0, 100))
    char_b.add_child(hrp_b)
    player_b.character = char_b

    # Base B setup
    base_b = Model(name="Base_2")
    base_b.set_attribute("OwnerUserId", 2002)
    egg_folder_b = Instance(name="IncubatingEggs")
    base_b.add_child(egg_folder_b)
    world.player_bases[2002] = base_b

    # Create Completed Egg for Player A
    egg_a = Model(name="Incubating_Common Rock")
    egg_core_a = Part(name="EggCore", position=Vector3(5, 0, 5))
    egg_a.primary_part = egg_core_a
    egg_a.add_child(egg_core_a)
    egg_folder_a.add_child(egg_a)

    state_a = IncubatingEggState(
        egg_id="guid-1",
        player=player_a,
        egg_name="Common Rock",
        finish_time=now - 10, # Completed 10s ago
        egg_model=egg_a
    )
    world.active_eggs[egg_a] = state_a

    results = []

    # Test 3: Player B calls claim with Player A's completed egg instance
    res3 = world.claim_hatched_egg(player_b, egg_a)
    assert res3 is False
    assert len(world.player_inventory.get(2002, [])) == 0
    assert egg_a in world.active_eggs
    results.append(("Player B calls claim with Player A's completed egg instance", "PASS"))

    # Test 4: Player B stands near Player A's egg (dist = 2) and calls claim
    hrp_b.position = Vector3(5, 0, 7) # 2 studs away
    res4 = world.claim_hatched_egg(player_b, egg_a)
    assert res4 is False
    assert len(world.player_inventory.get(2002, [])) == 0
    assert egg_a in world.active_eggs
    results.append(("Player B stands near Player A's egg and calls claim", "PASS"))

    # Test 5: Owner calls claim before completion
    egg_unfin = Model(name="Incubating_Unfinished")
    egg_unfin_core = Part(name="EggCore", position=Vector3(2, 0, 2))
    egg_unfin.primary_part = egg_unfin_core
    egg_unfin.add_child(egg_unfin_core)
    egg_folder_a.add_child(egg_unfin)
    state_unfin = IncubatingEggState(
        egg_id="guid-2",
        player=player_a,
        egg_name="Common Rock",
        finish_time=now + 500, # 500s remaining
        egg_model=egg_unfin
    )
    world.active_eggs[egg_unfin] = state_unfin
    res5 = world.claim_hatched_egg(player_a, egg_unfin)
    assert res5 is False
    assert egg_unfin in world.active_eggs
    results.append(("Owner calls claim before completion", "PASS"))

    # Test 1 & 2: Owner claims their completed egg (within interaction distance)
    # HRP is at (0, 0, 0), EggCore is at (5, 0, 5), distance ~ 7.07 studs <= 24
    res1 = world.claim_hatched_egg(player_a, egg_a)
    assert res1 is True
    assert len(world.player_inventory.get(1001, [])) == 1
    assert egg_a not in world.active_eggs
    results.append(("Owner claims completed egg by prompt / RemoteEvent", "PASS"))

    # Test 6: Owner sends claim repeatedly/concurrently after already claimed
    res6 = world.claim_hatched_egg(player_a, egg_a)
    assert res6 is False
    assert len(world.player_inventory.get(1001, [])) == 1 # Still 1, no duplicate
    results.append(("Owner sends claim repeatedly/concurrently", "PASS"))

    # Test 7: Owner claims after egg is destroyed/removed
    destroyed_egg = Model(name="DestroyedEgg")
    res7 = world.claim_hatched_egg(player_a, destroyed_egg)
    assert res7 is False
    results.append(("Owner claims after egg is destroyed/removed", "PASS"))

    print("ALL LOGIC ACCEPTANCE TESTS PASSED:")
    for name, status in results:
        print(f"  [{status}] {name}")

if __name__ == "__main__":
    run_acceptance_tests()
