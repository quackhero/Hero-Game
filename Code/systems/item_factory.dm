datum/item_factory
    var/list/loaded_items = list()

    // ============================================================
    // Load all items from Items.json
    // ============================================================
    proc/LoadAllItems()
        if(!fexists("Items.json"))
            world.log << "ERROR: Items.json not found!"
            return

        var/raw_text = file2text("Items.json")
        var/list/json_data = json_decode(raw_text)

        for(var/list/item_data in json_data)
            var/datum/item/I = src.BuildItem(item_data)
            if(I) src.loaded_items[item_data["id"]] = I

        world << "<b>[src.loaded_items.len] JSON Items Loaded!</b>"

    // ============================================================
    // Build a template item datum from a JSON object.
    // item_type drives which datum subtype is created.
    // ============================================================
    proc/BuildItem(list/data)
        var/itype = data["item_type"]
        var/datum/item/I

        // --- Equipment ---
        if(itype == "Weapon" || itype == "Armor" || itype == "Accessory")
            var/datum/item/equipment/E = new()
            E.item_type = itype

            if("weapon_type" in data)    E.weapon_type        = data["weapon_type"]
            if("attack_messages" in data) E.attack_messages   = data["attack_messages"]
            if("granted_skills" in data)  E.granted_skill_ids  = data["granted_skills"]
            if("granted_passives" in data) E.granted_passive_ids = data["granted_passives"]

            if("stat_bonuses" in data)
                var/list/bonuses = data["stat_bonuses"]
                if("strength" in bonuses)     E.strength_bonus     = bonuses["strength"]
                if("dexterity" in bonuses)    E.dexterity_bonus    = bonuses["dexterity"]
                if("intelligence" in bonuses) E.intelligence_bonus = bonuses["intelligence"]
                if("mind" in bonuses)         E.mind_bonus         = bonuses["mind"]
                if("vitality" in bonuses)     E.vitality_bonus     = bonuses["vitality"]
                if("resilience" in bonuses)   E.resilience_bonus   = bonuses["resilience"]
                if("max_hp" in bonuses)       E.max_hp_bonus       = bonuses["max_hp"]
                if("max_mp" in bonuses)       E.max_mp_bonus       = bonuses["max_mp"]

            I = E

        // --- Consumables & Ammo ---
        else if(itype == "Consumable" || itype == "Ammo")
            var/datum/item/consumable/C = new()
            C.item_type = itype

            if("ai_category" in data)  C.ai_category = data["ai_category"]
            if("target_type" in data)  C.target_type = data["target_type"]
            if("cures" in data)        C.cures        = data["cures"]

            // Build event timeline — prefer explicit "timeline" list; fall back to shorthand.
            if("timeline" in data)
                for(var/list/event_data in data["timeline"])
                    var/datum/skill_event/EV = skill_factory.BuildEvent(event_data)
                    if(EV) C.event_timeline += EV
            else
                var/effect = ("use_effect" in data) ? data["use_effect"] : ""
                if(effect == "heal")
                    var/datum/skill_event/heal/H = new()
                    H.formula = data["formula"]
                    C.event_timeline += H

                else if(effect == "heal_mp")
                    var/datum/skill_event/heal/H = new()
                    H.formula  = data["formula"]
                    H.heal_mp  = 1
                    C.event_timeline += H

                else if(effect == "damage")
                    var/datum/skill_event/damage/D = new()
                    D.formula = data["formula"]
                    if("damage_type" in data) D.damage_type = data["damage_type"]
                    C.event_timeline += D
                // "cure" — no timeline event needed; handled by C.cures in Use()

            I = C

        // --- Unknown / Misc ---
        else
            I = new /datum/item()
            I.item_type = itype

        // --- Shared fields ---
        if(I)
            I.name = data["name"]
            if("desc" in data)      I.desc      = data["desc"]
            if("buy_price" in data) I.buy_price = data["buy_price"]

        return I

    // ============================================================
    // MakeItem — create a fresh copy from a factory template.
    //
    // For consumables/ammo, event_timeline and cures are shared
    // list references (they are read-only at runtime, so this is safe).
    // Each copy gets its own `amount` so stack counts are independent.
    // ============================================================
    proc/MakeItem(item_id, amount = 1)
        var/datum/item/template = src.loaded_items[item_id]
        if(!template)
            world.log << "ERROR: item_factory.MakeItem() — unknown item ID: '[item_id]'"
            return null

        var/datum/item/I

        if(istype(template, /datum/item/equipment))
            var/datum/item/equipment/T = template
            var/datum/item/equipment/E = new()
            E.name            = T.name
            E.desc            = T.desc
            E.item_type       = T.item_type
            E.buy_price       = T.buy_price
            E.weapon_type         = T.weapon_type
            E.attack_messages     = T.attack_messages     // list ref — read-only
            E.granted_skill_ids   = T.granted_skill_ids   // list ref — read-only
            E.granted_passive_ids = T.granted_passive_ids // list ref — read-only
            E.strength_bonus      = T.strength_bonus
            E.dexterity_bonus     = T.dexterity_bonus
            E.intelligence_bonus  = T.intelligence_bonus
            E.mind_bonus          = T.mind_bonus
            E.vitality_bonus      = T.vitality_bonus
            E.resilience_bonus    = T.resilience_bonus
            E.max_hp_bonus        = T.max_hp_bonus
            E.max_mp_bonus        = T.max_mp_bonus
            I = E

        else if(istype(template, /datum/item/consumable))
            var/datum/item/consumable/T = template
            var/datum/item/consumable/C = new()
            C.name           = T.name
            C.desc           = T.desc
            C.item_type      = T.item_type
            C.buy_price      = T.buy_price
            C.ai_category    = T.ai_category
            C.target_type    = T.target_type
            C.event_timeline = T.event_timeline  // list ref — read-only
            C.cures          = T.cures           // list ref — read-only
            C.amount         = amount
            I = C

        else
            I = new /datum/item()
            I.name      = template.name
            I.desc      = template.desc
            I.item_type = template.item_type
            I.buy_price = template.buy_price
            I.amount    = amount

        return I
