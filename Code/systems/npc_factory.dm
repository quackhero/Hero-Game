// ============================================================
// NPC FACTORY
// Loads enemy/NPC definitions from NPCs.json and spawns
// mob/enemy instances on demand.
//
// Templates are stored as raw JSON lists — NOT pre-built mobs.
// SpawnNPC() creates a new mob/enemy on every call so multiple
// instances of the same type can coexist in battle.
// ============================================================

datum/npc_factory
    var/list/loaded_npcs = list()   // id → raw parsed JSON list (the template data)

    proc/LoadAllNPCs()
        if(!fexists("NPCs.json"))
            world.log << "ERROR: NPCs.json not found!"
            return
        var/raw_text = file2text("NPCs.json")
        var/list/json_data = json_decode(raw_text)
        for(var/list/npc_data in json_data)
            src.loaded_npcs[npc_data["id"]] = npc_data
        world << "<b>[src.loaded_npcs.len] JSON NPCs Loaded!</b>"

    proc/SpawnNPC(npc_id)
        var/list/data = src.loaded_npcs[npc_id]
        if(!data)
            world.log << "ERROR: npc_factory.SpawnNPC() — unknown NPC ID: '[npc_id]'"
            return null

        var/mob/enemy/E = new /mob/enemy()

        // --- Identity ---
        E.name = data["name"]
        if(data["race"] && data["race"] != "")
            E.race = data["race"]
        if(data["attribute"])
            E.attribute = data["attribute"]
        E.npc_id = npc_id

        // --- Stats (set derived vars directly, not base_*) ---
        // The base_* / UpdateStats() pipeline is for player equipment math.
        var/list/stats = data["stats"]
        if(stats)
            if("max_hp"       in stats) E.max_hp       = stats["max_hp"]
            if("max_mp"       in stats) E.max_mp       = stats["max_mp"]
            if("strength"     in stats) E.strength     = stats["strength"]
            if("dexterity"    in stats) E.dexterity    = stats["dexterity"]
            if("intelligence" in stats) E.intelligence = stats["intelligence"]
            if("mind"         in stats) E.mind         = stats["mind"]
            if("vitality"     in stats) E.vitality     = stats["vitality"]
            if("resilience"   in stats) E.resilience   = stats["resilience"]
        E.hp = E.max_hp
        E.mp = E.max_mp

        // --- Meta ---
        if(data["level"])   E.level      = data["level"]
        if(data["exp"])     E.base_exp   = data["exp"]
        if(data["gil"])     E.gil_reward = data["gil"]

        // --- AI Behavior ---
        if(data["difficulty"]) E.ai_difficulty = data["difficulty"]
        if(data["hero_status"]) E.hero_status  = data["hero_status"]

        // --- Target Type / Positional State ---
        var/ttype = data["target_type"]
        if(ttype == "Air")          E.is_aerial_target = 1
        else if(ttype == "Underground") E.is_burrowed  = 1

        // --- Attack Messages ---
        if(data["attack_messages"] && data["attack_messages"].len)
            E.attack_messages = data["attack_messages"].Copy()

        // --- Skills ---
        // JSON skill datums are shared singletons — safe to share across mobs.
        if(data["skills"])
            for(var/sid in data["skills"])
                var/datum/skill/S = skill_factory.loaded_skills[sid]
                if(S)
                    E.skills        += S
                    E.equipped_skills += S
                else
                    world.log << "WARNING: NPC [npc_id] references unknown skill: [sid]"

        // --- Consumable Items (carried into battle) ---
        // Each NPC gets fresh copies so amounts are independent.
        if(data["items"])
            for(var/item_id in data["items"])
                var/datum/item/I = item_factory.MakeItem(item_id)
                if(I)
                    E.equipped_items += I
                else
                    world.log << "WARNING: NPC [npc_id] references unknown item: [item_id]"

        // --- Equipment (weapon / armor / accessory) ---
        // Stat bonuses are baked into the JSON stat block — equipment is stored
        // mainly for: weapon attack_messages, weapon_type req checks, granted skills.
        if(data["equipment"])
            var/list/equip = data["equipment"]
            if(equip["weapon"] && equip["weapon"] != "")
                var/datum/item/equipment/W = item_factory.MakeItem(equip["weapon"])
                if(W) E.equipped_weapon = W
            if(equip["armor"] && equip["armor"] != "")
                var/datum/item/equipment/A = item_factory.MakeItem(equip["armor"])
                if(A) E.equipped_armor = A
            if(equip["accessory"] && equip["accessory"] != "")
                var/datum/item/equipment/Acc = item_factory.MakeItem(equip["accessory"])
                if(Acc) E.equipped_accessory = Acc

        // --- Loot Table ---
        // Stored as assoc list: item_id (string) → drop chance (%)
        // Turn_Engine.EndBattle handles both string IDs and legacy type paths.
        if(data["drops"])
            E.loot_table = data["drops"].Copy()

        // --- Battle Barks ---
        // Assoc list: bark_type → list of messages
        if(data["barks"])
            E.barks = data["barks"].Copy()

        // --- Future Systems (stored, not yet active) ---
        if(data["opportunities"])
            E.opportunities = data["opportunities"].Copy()
        if(data["finisher_opportunities"])
            E.finisher_opportunities = data["finisher_opportunities"].Copy()

        return E

var/datum/npc_factory/npc_factory = new()
