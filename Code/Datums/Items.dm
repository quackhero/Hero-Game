/**
 * ITEM DATUMS
 * Abstract data objects for inventory and equipment.
 */
datum/item
    var/name = "Item"
    var/desc = "A generic item."
    var/item_type = "Misc" // "Weapon", "Armor", "Accessory", "Consumable"
    
    // --- NEW: Stack Tracking for Ammo & Inventory ---
    var/amount = 1 
    
    // For Consumables
    proc/Use(mob/user, mob/target, datum/encounter/E)
        return 0 // Returns 1 if successfully used, 0 if canceled/failed

// --- EQUIPMENT BASE ---
datum/item/equipment
    // --- The New Six Attribute Bonuses ---
    var/strength_bonus = 0
    var/dexterity_bonus = 0
    var/intelligence_bonus = 0
    var/mind_bonus = 0
    var/vitality_bonus = 0
    var/resilience_bonus = 0
    
    var/max_hp_bonus = 0
    var/max_mp_bonus = 0
    
    // A list of skill paths this item grants while equipped
    var/list/granted_skills = list() 

// --- EXAMPLES ---
datum/item/equipment/weapon/iron_sword
    name = "Iron Sword"
    desc = "A standard, reliable blade. Grants the 'Bladerush' skill."
    item_type = "Weapon"
    
    // Updated to strength_bonus!
    strength_bonus = 5
    
    New()
        ..()
        // It grants the Bladerush skill you already made!

// --- CONSUMABLES BASE ---
// Defining this explicitly helps BYOND categorize them properly!
datum/item/consumable
    item_type = "Consumable"

datum/item/consumable/potion
    name = "Health Potion"
    desc = "Restores 50 HP."
    
    Use(mob/user, mob/target, datum/encounter/E)
        if(!target) target = user
        target.hp += 50
        target.ClampStats()
        world << "<b>[user.name] uses a Health Potion on [target.name], restoring 50 HP!</b>"
        return 1

datum/item/ether
    name = "Ether"
    desc = "Restores 50 MP."
datum/item/potion
    name = "Health Potion"
    desc = "Restores 50 HP."
    