var/datum/status_factory/status_factory = new()

datum/status_factory
    var/list/loaded_statuses = list()

    proc/LoadAllStatuses()
        if(!fexists("Statuses.json"))
            world.log << "ERROR: Statuses.json not found!"
            return

        var/raw_text = file2text("Statuses.json")
        var/list/json_data = json_decode(raw_text)

        for(var/list/status_data in json_data)
            var/datum/component/status/S = new()
            S.id = status_data["id"]
            S.name = status_data["name"]
            
            // Trigger / Counter logic
            if("trigger_condition" in status_data) S.trigger_condition = status_data["trigger_condition"]
            if("trigger_chance" in status_data) S.trigger_chance = status_data["trigger_chance"]
            if("reaction_skill_id" in status_data) S.reaction_skill_id = status_data["reaction_skill_id"]
            if("trigger_category" in status_data) S.trigger_category = status_data["trigger_category"]

            // --- DoT ---
            if("dot_amount" in status_data) S.dot_amount = status_data["dot_amount"]
            if("dot_type" in status_data) S.dot_type = status_data["dot_type"]
            if("dot_is_percent" in status_data) S.dot_is_percent = status_data["dot_is_percent"]
            if("dot_use_current" in status_data) S.dot_use_current = status_data["dot_use_current"]
            if("dot_cannot_kill" in status_data) S.dot_cannot_kill = status_data["dot_cannot_kill"]
            if("dot_delayed_burst" in status_data) S.dot_delayed_burst = status_data["dot_delayed_burst"]
            if("stack_double" in status_data) S.stack_double = status_data["stack_double"]

            // --- HoT ---
            if("hot_amount" in status_data) S.hot_amount = status_data["hot_amount"]
            if("hot_mp" in status_data) S.hot_mp = status_data["hot_mp"]

            // --- Stat Mods ---
            if("stat_mod" in status_data) S.stat_mod = status_data["stat_mod"]
            if("stat_amount" in status_data) S.stat_amount = status_data["stat_amount"]
            if("stat_percent" in status_data) S.stat_percent = status_data["stat_percent"]
            if("second_stat" in status_data) S.second_stat = status_data["second_stat"]
            if("second_stat_amount" in status_data) S.second_stat_amount = status_data["second_stat_amount"]
            if("second_stat_percent" in status_data) S.second_stat_percent = status_data["second_stat_percent"]

            // --- Crowd Control ---
            if("full_disable" in status_data) S.full_disable = status_data["full_disable"]
            if("shatter_mult" in status_data) S.shatter_mult = status_data["shatter_mult"]
            if("shatter_type" in status_data) S.shatter_type = status_data["shatter_type"]
            if("break_on_hit" in status_data) S.break_on_hit = status_data["break_on_hit"]
            if("skip_chance" in status_data) S.skip_chance = status_data["skip_chance"]
            if("disable_type" in status_data) S.disable_type = status_data["disable_type"]
            if("miss_chance" in status_data) S.miss_chance = status_data["miss_chance"]
            if("dodge_chance" in status_data) S.dodge_chance = status_data["dodge_chance"]
            if("dodge_once" in status_data) S.dodge_once = status_data["dodge_once"]
            if("confusion" in status_data) S.confusion = status_data["confusion"]

            // --- MP Mechanics ---
            if("sap_mp" in status_data) S.sap_mp = status_data["sap_mp"]

            // --- Special ---
            if("zombie_mode" in status_data) S.zombie_mode = status_data["zombie_mode"]
            if("reraise" in status_data) S.reraise = status_data["reraise"]
            if("invincible_thresh" in status_data) S.invincible_thresh = status_data["invincible_thresh"]
            if("mana_shield" in status_data) S.mana_shield = status_data["mana_shield"]
            if("kills_on_expire" in status_data) S.kills_on_expire = status_data["kills_on_expire"]

            // --- Damage Modifiers ---
            if("damage_resist_type" in status_data) S.damage_resist_type = status_data["damage_resist_type"]
            if("damage_resist_pct" in status_data) S.damage_resist_pct = status_data["damage_resist_pct"]
            if("damage_dealt_mult" in status_data) S.damage_dealt_mult = status_data["damage_dealt_mult"]

            // --- Targeting ---
            if("provoke" in status_data) S.provoke = status_data["provoke"]
            if("provoke_reverse" in status_data) S.provoke_reverse = status_data["provoke_reverse"]
            if("vanish" in status_data) S.vanish = status_data["vanish"]
            if("is_aerial" in status_data) S.is_aerial = status_data["is_aerial"]
            if("is_burrowed" in status_data) S.is_burrowed = status_data["is_burrowed"]

            // --- Skill Granting ---
            if("granted_skills" in status_data) S.granted_skill_ids = status_data["granted_skills"]
            if("granted_passives" in status_data) S.granted_passive_ids = status_data["granted_passives"]
            if("lock_position" in status_data) S.lock_position = status_data["lock_position"]

            src.loaded_statuses[S.id] = S
            
        world << "<b>[src.loaded_statuses.len] JSON Statuses Loaded!</b>"