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

        // For basic attacks, use the weapon's computed damage type (subtype + elemental tag)
        // stored on the caster mob. Falls back to the event's own damage_type for all other skills,
        // keeping full backwards compatibility with hardcoded "Physical", "Fire", etc.
        var/eff_type = src.damage_type
        if(S && S.id == "basic_attack" && ("override_attack_damage_type" in user.vars) && user.override_attack_damage_type != "")
            eff_type = user.override_attack_damage_type

        if(src.hitrate < 100 && !prob(src.hitrate))
            world << "<i>[user.name] missed [target.name]!</i>"
            return

        var/base_dmg = parser.Evaluate(src.formula, user, target)

        // Damage Boost / Damage Break: multiply outgoing damage by attacker's status mult.
        // Applied before the pipeline so the multiplier compounds with elemental modifiers.
        for(var/datum/component/status/C in user.components)
            if(C.damage_dealt_mult != 0)
                base_dmg = round(base_dmg * C.damage_dealt_mult)

        // Show the skill's flavor message.
        // Uses base_dmg (pre-pipeline) for any (dmg) placeholder — the final resolved
        // damage and elemental context are shown by TakeDamage.
        var/msg = src.txt
        if(msg)
            // 1. Names
            msg = replacetext(msg, "(I)", user.name)
            msg = replacetext(msg, "(user)", user.name)
            msg = replacetext(msg, "(E)", target.name)
            msg = replacetext(msg, "(enemy)", target.name)
            msg = replacetext(msg, "(target)", target.name)

            // 2. Damage
            msg = replacetext(msg, "\[dmg]", "[base_dmg]")
            msg = replacetext(msg, "(dmg)", "[base_dmg]")

            // 3. Type
            msg = replacetext(msg, "\[type]", eff_type)
            msg = replacetext(msg, "(type)", eff_type)

            world << "<b>[msg]</b>"
        else
            world << "<b>[user.name]</b> uses <b>[eff_type]</b> on <b>[target.name]</b>!"

        // Resilience, elemental cycle, affinity, and defending are all resolved
        // inside TakeDamage via DamageContext.ResolveDamage(). Pass bypass through
        // so skills that ignore resilience (bypass=-1) still work correctly.
        var/actual_dmg = target.TakeDamage(base_dmg, user, eff_type, 1, src.bypass)

        if(src.leech > 0 && actual_dmg > 0)
            var/heal = round(actual_dmg * src.leech)
            if(heal > 0)
                user.hp += heal
                user.ClampStats()
                world << "<i>[user.name] absorbs [heal] HP!</i>"

        // --- THE TRIGGER / COUNTER HOOK ---
        if(target && target.hp > 0 && user != target)
            var/counter_fired = 0

            // 1. Check PASSIVE Skills (only equipped passives with OnDamaged trigger)
            for(var/datum/skill/reaction in target.equipped_skills)
                if(!reaction.is_passive) continue
                if(reaction.trigger_condition == "OnDamaged")
                    // NEW: Category Filter Check!
                    if(reaction.trigger_category == "Any" || reaction.trigger_category == S.category)
                        if(prob(reaction.trigger_chance))
                            world << "<i><font color='#FFA500'>[target.name] reacts with [reaction.name]!</font></i>"
                            reaction.ProcessTimeline(target, user, E, 1)
                            counter_fired = 1
                            break 

            // 2. Check ACTIVE Statuses (Your Components List!)
            if(!counter_fired && target.components)
                for(var/datum/component/status/stance in target.components)
                    if(stance.trigger_condition == "OnDamaged" && stance.reaction_skill_id)
                        // NEW: Category Filter Check!
                        if(stance.trigger_category == "Any" || stance.trigger_category == S.category)
                            if(prob(stance.trigger_chance))
                                var/datum/skill/reaction_skill = skill_factory.loaded_skills[stance.reaction_skill_id]
                                if(reaction_skill)
                                    world << "<i><font color='#FFA500'>[target.name]'s [stance.name] activates!</font></i>"
                                    reaction_skill.ProcessTimeline(target, user, E, 1)
                                    break

/**
 * Heal Event: Handles restoration
 * Set heal_mp = 1 to restore MP instead of HP (used by items like Ether).
 */
datum/skill_event/heal
    var/formula = "0"
    var/heal_mp = 0   // If 1, restores MP instead of HP

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/amt = round(parser.Evaluate(src.formula, user, target))

        // --- MP restore path ---
        if(src.heal_mp)
            if(!target || target.is_dead) return
            target.mp += amt
            target.ClampStats()
            world << "<b>[target.name] recovers [amt] MP!</b>"
            return

        // --- HP restore path ---
        // Revive skills call Revive() explicitly; regular heals cannot resurrect.
        if(S && (S.targeting_flags & TARGET_REVIVE) && target.is_dead)
            target.Revive(amt)
            world << "<b>[target.name] is restored for [amt] HP!</b>"
        else
            if(!target || target.is_dead) return
            // Route through ApplyHeal so Zombie status converts heals to damage
            if(hascall(target, "ApplyHeal"))
                target.ApplyHeal(amt, user)
            else
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
    var/status_type = "" // Now a string ID
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
    var/list/false_events = list()

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/mob/actual_target = target ? target : user
        if(parser.Evaluate(src.formula, user, actual_target))
            for(var/datum/skill_event/EV in src.true_events)
                EV.Run(user, target, S, E)
                if(EV.delay > 0) sleep(EV.delay)
        else
            for(var/datum/skill_event/EV in src.false_events)
                EV.Run(user, target, S, E)
                if(EV.delay > 0) sleep(EV.delay)