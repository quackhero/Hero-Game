/**
 * ITEM DATUMS
 * Abstract data objects for inventory and equipment.
 */
datum/item
    var/name = "Item"
    var/desc = "A generic item."
    var/item_type = "Misc" // "Weapon", "Armor", "Accessory", "Consumable"
    
    // For Consumables
    proc/Use(mob/user, mob/target, datum/encounter/E)
        return 0 // Returns 1 if successfully used, 0 if canceled/failed

// --- EQUIPMENT BASE ---
datum/item/equipment
    var/atk_bonus = 0
    var/def_bonus = 0
    var/spd_bonus = 0
    var/max_hp_bonus = 0
    var/max_mp_bonus = 0
    
    // A list of skill paths this item grants while equipped
    var/list/granted_skills = list() 

// --- EXAMPLES ---
datum/item/equipment/weapon/iron_sword
    name = "Iron Sword"
    desc = "A standard, reliable blade. Grants the 'Bladerush' skill."
    item_type = "Weapon"
    atk_bonus = 5
    
    New()
        ..()
        // It grants the Bladerush skill you already made!
        src.granted_skills += /datum/skill/bladerush

datum/item/consumable/potion
    name = "Health Potion"
    desc = "Restores 50 HP."
    item_type = "Consumable"
    
    Use(mob/user, mob/target, datum/encounter/E)
        if(!target) target = user
        target.hp += 50
        target.ClampStats()
        world << "<b>[user.name] uses a Health Potion on [target.name], restoring 50 HP!</b>"
        return 1
datum/item/potion
    name = "Potion"

datum/item/ether
    name = "Ether"