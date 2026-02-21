datum/skill_factory
    // This proc handles the "&&" logic from your document
    proc/CreateSkillFromData(list/data)
        var/datum/skill/S = new()
        S.name = data["Name"]
        S.cost = text2num(data["Cst"])
        
        // 1. Parse Targeting Flags
        S.targeting_flags = src.ParseFlags(data["Type"])
        
        // 2. Break down the lists (MsgList, DmgList, SndList, DelayList)
        var/list/msgs   = splittext(data["MsgList"], "&&")
        var/list/dmgs   = splittext(data["DmgList"], "&&")
        var/list/snds   = splittext(data["SndList"], "&&")
        var/list/delays = splittext(data["DelayList"], "&&")

        // 3. Assemble the Timeline
        // We iterate through the longest list to ensure all effects are captured
        var/max_steps = max(msgs.len, dmgs.len, snds.len)
        
        for(var/i = 1 to max_steps)
            // Determine timing for this step
            var/current_delay = (i <= delays.len) ? text2num(delays[i]) : text2num(data["Rapid"])
            if(i == max_steps && data["FinalCharge"]) 
                current_delay = text2num(data["FinalCharge"])

            // Add Message Event
            if(i <= msgs.len && msgs[i] != "")
                var/datum/skill_event/message/msg_ev = new()
                msg_ev.txt = msgs[i]
                msg_ev.delay = current_delay
                S.event_timeline += msg_ev

            // Add Sound Event
            if(i <= snds.len && snds[i] != "")
                var/datum/skill_event/sound/snd_ev = new()
                snd_ev.sound_file = snds[i]
                S.event_timeline += snd_ev

            // Add Damage Event
            if(i <= dmgs.len && dmgs[i] != "0")
                var/datum/skill_event/damage/dmg_ev = new()
                dmg_ev.formula = dmgs[i]
                dmg_ev.damage_type = data["Dmgtype"]
                dmg_ev.bypass_value = text2num(data["Bypass"])
                S.event_timeline += dmg_ev

        // 4. Add Post-Skill Components (Leech, Inflict)
        if(data["Leech"])
            S.components += new /datum/component/leech(text2num(data["Leech"]))
            
        return S

    proc/ParseFlags(type_string)
        var/flags = 0
        if(findtext(type_string, "Target")) flags |= TARGET_SINGLE
        if(findtext(type_string, "AOE"))    flags |= TARGET_AOE
        if(findtext(type_string, "Aerial")) flags |= TARGET_AERIAL
        // ... and so on for all your types
        return flags