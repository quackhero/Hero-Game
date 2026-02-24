datum/skill_factory
    var/list/loaded_skills = list()

    proc/LoadAllSkills()
        if(!fexists("Skills.json"))
            world.log << "ERROR: Skills.json not found!"
            return

        var/raw_text = file2text("Skills.json")
        var/list/json_data = json_decode(raw_text)

        for(var/list/skill_data in json_data)
            var/datum/skill/S = src.BuildSkill(skill_data)
            src.loaded_skills[skill_data["id"]] = S
            
        world << "<b>[src.loaded_skills.len] JSON Skills Loaded!</b>"

    proc/BuildSkill(list/data)
        var/datum/skill/S = new()
        S.name = data["name"]
        S.cost = data["cost"]

        if("hp_cost" in data) S.hp_cost = data["hp_cost"]
        if("ammo_type" in data) S.ammo_type = data["ammo_type"]
        if("ammo_cost" in data) S.ammo_cost = data["ammo_cost"]
        
        // 1. Bitflags
        if(data["target_flags"])
            for(var/flag_str in data["target_flags"])
                if(flag_str == "TARGET_SINGLE") S.targeting_flags |= TARGET_SINGLE
                if(flag_str == "TARGET_AOE")    S.targeting_flags |= TARGET_AOE
                if(flag_str == "TARGET_HEAL")   S.targeting_flags |= TARGET_HEAL
                if(flag_str == "TARGET_SELF")   S.targeting_flags |= TARGET_SELF

        // 2. Guardrails
        if(data["requirements"])
            var/list/reqs = data["requirements"]
            if("target_dead" in reqs) S.can_target_dead = reqs["target_dead"]
            if("fizzle_chance" in reqs) S.fizzle_chance = reqs["fizzle_chance"]
            if("req_target_name" in reqs) S.req_target_name = reqs["req_target_name"]
            if("req_target_race" in reqs) S.req_target_race = reqs["req_target_race"]
            if("req_target_hp" in reqs) S.req_target_hp = reqs["req_target_hp"]
            if("req_target_status" in reqs) S.req_target_status = reqs["req_target_status"]
            if("req_user_status" in reqs) S.req_user_status = reqs["req_user_status"]

        // 3. Build the Timeline using the new BuildEvent proc
        if(data["timeline"])
            for(var/list/event_data in data["timeline"])
                var/datum/skill_event/EV = src.BuildEvent(event_data)
                if(EV) S.event_timeline += EV

        return S

    // --- NEW: The Recursive Event Builder ---
    // This allows conditions to have their own mini-timelines
    proc/BuildEvent(list/event_data)
        var/type = event_data["type"]
        var/datum/skill_event/EV

        switch(type)
            if("message")
                var/datum/skill_event/message/M = new()
                M.txt = event_data["text"]
                EV = M
                
            if("damage")
                var/datum/skill_event/damage/D = new()
                if("text" in event_data) D.txt = event_data["text"]
                D.formula = event_data["formula"]
                if("damage_type" in event_data) D.damage_type = event_data["damage_type"]
                EV = D
                
            if("heal")
                var/datum/skill_event/heal/H = new()
                H.formula = event_data["formula"]
                EV = H
                
            if("inflict")
                var/datum/skill_event/inflict/I = new()
                I.status_type = text2path(event_data["status"])
                I.duration = event_data["duration"]
                if("amount" in event_data) I.amount = event_data["amount"]
                if("chance" in event_data) I.chance = event_data["chance"]
                EV = I

            if("stat_mod")
                var/datum/skill_event/stat_mod/SM = new()
                SM.stat_to_mod = event_data["stat"]
                SM.formula = event_data["formula"]
                SM.mod_type = uppertext(event_data["mod_type"])
                // NEW: Read the target type from JSON
                if("target_type" in event_data) SM.target_type = event_data["target_type"]
                EV = SM

            if("condition")
                var/datum/skill_event/condition/C = new()
                C.formula = event_data["formula"]
                
                // If the condition has an "if_true" list, build those events too!
                if(event_data["if_true"])
                    for(var/list/sub_event in event_data["if_true"])
                        var/datum/skill_event/SUB = src.BuildEvent(sub_event)
                        if(SUB) C.true_events += SUB
                EV = C

            if("damage")
                var/datum/skill_event/damage/D = new()
                if("text" in event_data) D.txt = event_data["text"]
                D.formula = event_data["formula"]
                if("damage_type" in event_data) D.damage_type = event_data["damage_type"]
                
                // --- NEW: Load the Advanced Math ---
                if("hitrate" in event_data) D.hitrate = event_data["hitrate"]
                if("bypass" in event_data) D.bypass = event_data["bypass"]
                if("leech" in event_data) D.leech = event_data["leech"]
                
                EV = D

        if(EV && "delay" in event_data) 
            EV.delay = event_data["delay"]
            
        return EV