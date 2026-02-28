// ============================================================
// BASE ITEM
// ============================================================
datum/item
    var/name     = "Item"
    var/desc     = "A generic item."
    var/item_type = "Misc"   // "Weapon", "Armor", "Accessory", "Consumable", "Ammo"
    var/amount   = 1
    var/buy_price = 0

    proc/Use(mob/user, mob/target, datum/encounter/E)
        return 0   // Returns 1 on success, 0 on failure/cancel

// ============================================================
// EQUIPMENT  (Weapons, Armor, Accessories)
// ============================================================
datum/item/equipment
    // Weapon-only: the weapon category required by skill req_weapon_type
    var/weapon_type = ""

    // Weapon-only: flavor lines randomly picked during BasicAttack.
    // Placeholders: (I)/(user) = attacker name, (target)/(E) = target name
    var/list/attack_messages = null

    // IDs of skills/passives the mob gains while this piece is equipped.
    // Managed by UpdateStats() — added and removed automatically on equip/unequip.
    var/list/granted_skill_ids   = null
    var/list/granted_passive_ids = null

    // Flat stat bonuses added on top of base stats by UpdateStats()
    var/strength_bonus     = 0
    var/dexterity_bonus    = 0
    var/intelligence_bonus = 0
    var/mind_bonus         = 0
    var/vitality_bonus     = 0
    var/resilience_bonus   = 0
    var/max_hp_bonus       = 0
    var/max_mp_bonus       = 0

// ============================================================
// CONSUMABLES & AMMO
// ============================================================
datum/item/consumable
    item_type = "Consumable"

    // Hint for the AI on when/how to use this item.
    // Values: "hp_restore", "mp_restore", "status_clear", "offensive", "buff", ""
    var/ai_category = ""

    // How to pick targets in battle.
    // Values: "ally_single", "enemy_single", "ally_aoe", "enemy_aoe", "self"
    var/target_type = "ally_single"

    // List of datum/skill_event instances built by the item factory.
    // Executed in order when Use() is called — same event system as skills.
    var/list/event_timeline = list()

    // List of status IDs (strings) to remove from the target on use.
    // Populated by the factory from the JSON "cures" field.
    var/list/cures = null

    Use(mob/user, mob/target, datum/encounter/E)
        if(!target) target = user

        // 1. Cure statuses listed in the cures field
        if(src.cures && hascall(target, "GetStatus") && hascall(target, "RemoveStatus"))
            for(var/status_id in src.cures)
                var/datum/component/status/C = target.GetStatus(status_id)
                if(C) target.RemoveStatus(C)

        // 2. Run event timeline (heal, damage, inflict, etc.)
        for(var/datum/skill_event/EV in src.event_timeline)
            EV.Run(user, target, null, E)
            if(EV.delay > 0) sleep(EV.delay)

        return 1