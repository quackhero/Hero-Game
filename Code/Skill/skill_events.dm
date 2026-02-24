/**
 * Message Event: Handles MsgList
 */
datum/skill_event/message
    var/txt = ""
    is_global = 1 
    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!src.txt) return
        var/msg = src.txt
        msg = replacetext(msg, "(I)", user.name)
        msg = replacetext(msg, "(user)", user.name)
        if(target) 
            msg = replacetext(msg, "(E)", target.name)
            msg = replacetext(msg, "(enemy)", target.name)
            msg = replacetext(msg, "(target)", target.name)
        world << "<b>[msg]</b>"

/**
 * Damage Event: Handles Health Reduction & Reactions
 */
datum/skill_event/damage
    var/txt = ""
    var/formula = "0"
    var/damage_type = "Physical"
    var/hitrate = 100   
    var/bypass = 0      
    var/leech = 0.0     

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target) return
        if(src.hitrate < 100 && !prob(src.hitrate))
            world << "<i>[user.name] missed [target.name]!</i>"
            return 

        var/base_dmg = parser.Evaluate(src.formula, user, target)
        var/res = (src.bypass == -1) ? 0 : max(0, target.resilience - src.bypass)
        var/final_dmg = max(1, base_dmg - res)
        
        var/msg = src.txt
        if(msg)
            // 1. Names
            msg = replacetext(msg, "(I)", user.name)
            msg = replacetext(msg, "(user)", user.name)
            msg = replacetext(msg, "(E)", target.name)
            msg = replacetext(msg, "(enemy)", target.name)
            msg = replacetext(msg, "(target)", target.name)
            
            // 2. Damage (Notice the backslash \ before the bracket!)
            msg = replacetext(msg, "\[dmg]", "[final_dmg]")
            msg = replacetext(msg, "(dmg)", "[final_dmg]")
            
            // 3. Type
            msg = replacetext(msg, "\[type]", src.damage_type)
            msg = replacetext(msg, "(type)", src.damage_type)
            
            world << "<b>[msg]</b>"
        else
            world << "<b>[user.name]</b> deals <b>[final_dmg] [src.damage_type]</b> damage to <b>[target.name]</b>!"

        target.TakeDamage(final_dmg, user, src.damage_type, 1) // 1 = Silent

        if(src.leech > 0)
            var/heal = round(final_dmg * src.leech)
            if(heal > 0)
                user.hp += heal
                user.ClampStats() 
                world << "<i>[user.name] absorbs [heal] HP!</i>"

        // --- THE TRIGGER / COUNTER HOOK ---
        // 1. Ensure the target is alive.
        // 2. Ensure the user didn't just hit themselves (prevents infinite self-damage loops).
        if(target && target.hp > 0 && user != target)
            for(var/datum/skill/reaction in target.skills)
                if(reaction.trigger_condition == "OnDamaged")
                    if(prob(reaction.trigger_chance))
                        world << "<i><font color='#FFA500'>[target.name] reacts with [reaction.name]!</font></i>"
                        
                        // FLIP THE SCRIPT: The target becomes the user, the attacker becomes the target!
                        // FIXED: Added the ', 1' at the end to properly flag this as a reaction!
                        reaction.ProcessTimeline(target, user, E, 1)
                        
                        break // Stop after one counter to prevent spam!

/**
 * Heal Event: Handles restoration
 */
datum/skill_event/heal
    var/formula = "0"

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/amt = parser.Evaluate(src.formula, user, target)
        target.hp += amt
        target.ClampStats()
        world << "<b>[target.name] is restored for [amt] HP!</b>"

/**
 * Sound Event: Handles playing audio
 */
datum/skill_event/sound
    var/sound_file
    is_global = 1 

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!src.sound_file) return
        var/sound/S_file = sound(src.sound_file)
        for(var/mob/M in E.all_participants)
            M << S_file

/**
 * Status Event: Handles Inflict
 */
datum/skill_event/inflict
    var/status_type
    var/chance = 100
    var/amount = 0
    var/duration = 3

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!prob(src.chance)) return
        if(target && hascall(target, "ApplyStatus")) 
            target.ApplyStatus(src.status_type, src.duration, src.amount)

/**
 * Stat Modification Event: Buffs/Debuffs
 */
datum/skill_event/stat_mod
    var/stat_to_mod = "" 
    var/formula = "0"
    var/target_type = "Target" 
    var/mod_type = "ADD" 

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/mob/T = (lowertext(src.target_type) == "self") ? user : target
        if(!T) return
        var/val = parser.Evaluate(src.formula, user, T)
        
        var/v_name = ""
        switch(src.stat_to_mod)
            if("STR") v_name = "base_strength"
            if("DEX") v_name = "base_dexterity"
            if("INT") v_name = "base_intelligence"
            if("MND") v_name = "base_mind"
            if("VIT") v_name = "base_vitality"
            if("RES") v_name = "base_resilience"
        
        if(!v_name || !(v_name in T.vars)) return

        if(src.mod_type == "ADD") T.vars[v_name] += val
        else if(src.mod_type == "SUB") T.vars[v_name] -= val
        else T.vars[v_name] = val

        T.UpdateStats()

/**
 * Conditional Branch Event: Branching Logic
 */
datum/skill_event/condition
    var/formula = ""     
    var/list/true_events = list() 

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/mob/actual_target = target ? target : user
        if(parser.Evaluate(src.formula, user, actual_target))
            for(var/datum/skill_event/EV in src.true_events)
                EV.Run(user, target, S, E)
                if(EV.delay > 0) sleep(EV.delay)