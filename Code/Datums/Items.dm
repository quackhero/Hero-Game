datum/item
    var/name = "Item"
    var/desc = "A generic item."
    var/item_type = "Misc" // "Weapon", "Armor", "Accessory", "Consumable"
    var/amount = 1

    proc/Use(mob/user, mob/target, datum/encounter/E)
        return 0 // Returns 1 if successfully used, 0 if canceled/failed

// --- EQUIPMENT ---
datum/item/equipment
    var/strength_bonus = 0
    var/dexterity_bonus = 0
    var/intelligence_bonus = 0
    var/mind_bonus = 0
    var/vitality_bonus = 0
    var/resilience_bonus = 0
    var/max_hp_bonus = 0
    var/max_mp_bonus = 0

datum/item/equipment/weapon/iron_sword
    name = "Iron Sword"
    desc = "A standard, reliable blade."
    item_type = "Weapon"
    strength_bonus = 5

// --- CONSUMABLES ---
datum/item/consumable
    item_type = "Consumable"
    // Hint for the AI to know how to use this item.
    // Values: "hp_restore", "mp_restore", "status_clear", "offensive", ""
    var/ai_category = ""

datum/item/consumable/potion
    name = "Health Potion"
    desc = "Restores 50 HP."
    ai_category = "hp_restore"

    Use(mob/user, mob/target, datum/encounter/E)
        if(!target) target = user
        target.hp += 50
        target.ClampStats()
        world << "<b>[user.name] uses a Health Potion on [target.name], restoring 50 HP!</b>"
        return 1

datum/item/consumable/ether
    name = "Ether"
    desc = "Restores 50 MP."
    ai_category = "mp_restore"

    Use(mob/user, mob/target, datum/encounter/E)
        if(!target) target = user
        target.mp += 50
        target.ClampStats()
        world << "<b>[user.name] uses an Ether on [target.name], restoring 50 MP!</b>"
        return 1
