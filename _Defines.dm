var/datum/skill_parser/skill_parser = new()
var/datum/skill_factory/skill_factory = new()

// --- Targeting Bitflags ---
// These allow Target, AOE, Aerial, and Deflect to be used in tandem.
#define TARGET_SINGLE    1
#define TARGET_AOE       2
#define TARGET_AERIAL    4
#define TARGET_DEFLECT   8
#define TARGET_HEAL      16
#define TARGET_REVIVE    32
#define TARGET_SELF      64

// --- AOE Types (Mapping your Arg List) ---
#define AOE_MARK         1  // Only affects marked
#define AOE_TARGET       2  // Damages 1 target + everyone else
#define AOE_FOCUSED      5  // Damages everyone including target

// --- Skill Flags ---
#define SKILL_UNINTERRUPT_NONE 0
#define SKILL_UNINTERRUPT_STD  1
#define SKILL_UNINTERRUPT_DEATH 2

// --- ATB Engine ---
#define ATB_GAUGE_MAX 100


// --- Damage Types ---
#define DMG_PHYSICAL "Physical"
#define DMG_FIRE     "Fire"
#define DMG_ICE      "Ice"
#define DMG_NECROTIC "Necrotic"

// Global Signal Constants
#define SIG_TURN_START    "ON_TURN_START"
#define SIG_TURN_ACTION   "ON_TURN_ACTION"
#define SIG_ON_DAMAGE     "ON_DAMAGE_DEALT"
#define SIG_ON_DAMAGED    "ON_DAMAGE_TAKEN"
#define SIG_ON_DODGE      "ON_DODGE"
#define SIG_ON_KILL       "ON_KILL"
#define SIG_ON_DEATH      "ON_DEATH"
#define SIG_ON_INFECT     "ON_INFECT_APPLIED"
#define SIG_ON_EXPIRE     "ON_STATUS_EXPIRE"