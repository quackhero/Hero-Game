var/datum/skill_factory/skill_factory = new()
var/datum/item_factory/item_factory = new()
var/datum/npc_factory/npc_factory = new()
var/datum/element_factory/element_factory = new()

// --- Targeting Bitflags ---
// These allow Target, AOE, Aerial, and Deflect to be used in tandem.
#define TARGET_SINGLE    1
#define TARGET_AOE       2
#define TARGET_AERIAL    4
#define TARGET_DEFLECT   8
#define TARGET_HEAL      16
#define TARGET_REVIVE    32
#define TARGET_SELF      64
#define TARGET_MARKED    128  // AOE hits only mobs with is_marked == 1

// --- AOE Types (Mapping your Arg List) ---
#define AOE_MARK         1  // Only affects marked
#define AOE_TARGET       2  // Damages 1 target + everyone else
#define AOE_FOCUSED      5  // Damages everyone including target

// --- Skill Flags ---
#define SKILL_UNINTERRUPT_NONE 0
#define SKILL_UNINTERRUPT_STD  1
#define SKILL_UNINTERRUPT_DEATH 2

// --- Positional State Bitflags (skill/proc/position_flags) ---
// Define which positional states a skill can target.
// Default (0) is treated as POS_GROUND only.
#define POS_GROUND    1   // Skill hits Grounded targets
#define POS_AERIAL    2   // Skill hits Airborne targets
#define POS_BURROWED  4   // Skill hits Burrowed targets
#define POS_ANY       7   // Skill hits all positional states

// --- ATB Engine ---
#define ATB_GAUGE_MAX       1000   // Raised; used only for display/legacy references
#define ATB_BASE_WAIT       150    // Baseline ticks between turns (30s at tick_rate=2)
#define ATB_DEX_FACTOR      0.03   // How much each DEX point reduces wait
#define ATB_MIN_WAIT        20     // Hard floor — no character acts faster than this
#define WEIGHT_ATB_FACTOR   0.8    // Each weight unit adds this many ticks to wait
#define WEIGHT_DODGE_FACTOR 0.4    // Each weight unit reduces effective dodge DEX by this
#define BASE_DODGE_CAP      30     // Max dodge % without the dodge passive
#define FULL_DODGE_CAP      75     // Max dodge % with the dodge passive equipped


// --- Damage Types ---
#define DMG_PHYSICAL "Physical"
#define DMG_FIRE     "Fire"
#define DMG_ICE      "Ice"
#define DMG_NECROTIC "Necrotic"

// Global Signal Constants
// Names match the literal strings sent by SendSignal() in Base.dm and Turn_Engine.dm.
#define SIG_TURN_START        "ON_TURN_START"
#define SIG_TURN_END          "ON_TURN_END"
#define SIG_TURN_ACTION       "ON_TURN_ACTION"

// --- Damage signals ---
#define SIG_DAMAGED           "SIG_DAMAGED"        // Fires on the VICTIM in TakeDamage
#define SIG_DEALT_DAMAGE      "SIG_DEALT_DAMAGE"   // Fires on the ATTACKER in TakeDamage
#define SIG_TOOK_ZERO_DAMAGE  "SIG_TOOK_ZERO_DAMAGE"  // Victim took 0 final HP damage
#define SIG_DEALT_ZERO_DAMAGE "SIG_DEALT_ZERO_DAMAGE" // Attacker dealt 0 final HP damage

// --- Death signals ---
#define SIG_DYING             "SIG_DYING"   // Before is_dead=1; Re-Raise fires here via OnSignal
#define SIG_DEATH             "SIG_DEATH"   // After is_dead=1; death confirmed
#define SIG_KILL              "SIG_KILL"    // Fires on the killer mob, passed_val = defeated mob
#define SIG_DOWNED            "SIG_DOWNED"  // HP hit 0 or below (may revive before is_dead)

// --- Status signals ---
#define SIG_STATUS_APPLIED    "SIG_STATUS_APPLIED"   // New status applied, passed_val = status_id
#define SIG_STATUS_REMOVED    "SIG_STATUS_REMOVED"   // Status removed,  passed_val = status_id
#define SIG_ON_INFECT         "ON_INFECT_APPLIED"    // Fires on new status apply, passed_val = status datum
#define SIG_ON_EXPIRE         "ON_STATUS_EXPIRE"     // Fires before status is deleted, passed_val = status datum

// --- Turn-state signals ---
#define SIG_HURT              "SIG_HURT"      // HP < 30% at turn start
#define SIG_FULL_HP           "SIG_FULL_HP"   // HP at max at turn start
#define SIG_ALONE             "SIG_ALONE"     // All allies dead/downed at turn start
#define SIG_WAIT              "SIG_WAIT"      // Mob chose Guard or Pass

// --- Attack signals ---
#define SIG_PRE_ATTACK        "SIG_PRE_ATTACK"   // Fires in BasicAttack before Execute()
#define SIG_POST_ATTACK       "SIG_POST_ATTACK"  // Fires in BasicAttack after Execute()

// --- Dodge ---
#define SIG_ON_DODGE          "ON_DODGE"
#define SIG_DODGE             "SIG_DODGE"

// --- Battle entry ---
#define SIG_JOIN_BATTLE       "SIG_JOIN_BATTLE"  // Fires once per mob when they enter the encounter