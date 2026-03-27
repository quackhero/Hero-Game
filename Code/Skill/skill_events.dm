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

        // --- Guardian / Shield redirect ---
        // Check if the intended target is protected; if so, hit the guardian/shield instead.
        if(E && E.guardians && E.shields)
            var/mob/redirected = E.RedirectTarget(target, user)
            if(redirected != target)
                world << "<i>[redirected.name] intercepts the attack for [target.name]!</i>"
                target = redirected

        // --- Dodge check — DEX contest for basic attacks and dodgeable skills ---
        if(S && (S.id == "basic_attack" || S.dodgeable))
            if(user && hascall(target, "CalculateDodgeChance"))
                var/dodge_pct = target.CalculateDodgeChance(user)
                if(prob(dodge_pct))
                    world << "<i>[target.name] dodges [user.name]'s attack!</i>"
                    target.SendSignal(SIG_DODGE)
                    return

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
 * Set target_self = 1 to inflict the status on the user instead of the target.
 */
datum/skill_event/inflict
    var/status_type = "" // Now a string ID
    var/chance = 100
    var/amount = 0
    var/duration = 3
    var/target_self = 0  // Step 8: if 1, inflict on caster instead of target

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!prob(src.chance)) return
        // Step 8: redirect to caster when target_self is set
        var/mob/actual_target = src.target_self ? user : target
        if(actual_target && hascall(actual_target, "ApplyStatus"))
            actual_target.ApplyStatus(src.status_type, src.duration, src.amount)

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

// ============================================================
// Step 10: Mark Event — applies the is_marked flag to a target
// Skills with TARGET_MARKED AOE will only hit marked mobs.
// ============================================================
datum/skill_event/mark
    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target) return
        target.is_marked = 1
        world << "<i>[target.name] has been marked!</i>"

// ============================================================
// Step 16: AddSkill / RemoveSkill Events
// Temporarily adds or removes a skill from a mob's equipped list.
// ============================================================
datum/skill_event/addskill
    var/skill_id = ""

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target || !src.skill_id) return
        var/datum/skill/SK = skill_factory.loaded_skills[src.skill_id]
        if(SK && !(SK in target.equipped_skills))
            target.equipped_skills += SK
            target.skills += SK
            world << "<i>[target.name] gained [SK.name]!</i>"

datum/skill_event/removeskill
    var/skill_id = ""

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target || !src.skill_id) return
        var/datum/skill/SK = skill_factory.loaded_skills[src.skill_id]
        if(SK)
            target.equipped_skills -= SK
            target.skills -= SK
            world << "<i>[target.name] lost [SK.name]!</i>"

// ============================================================
// Step 17: Transform Event
// Replaces the user with a different NPC mid-battle (boss phase change).
// carry_hp = 1 preserves HP% from the old form to the new one.
// ============================================================
datum/skill_event/transform
    var/npc_id  = ""
    var/carry_hp = 0

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!user || !E || !src.npc_id) return

        // 1. Spawn the replacement NPC
        var/mob/enemy/new_mob = npc_factory.SpawnNPC(src.npc_id)
        if(!new_mob) return

        // 2. Insert into encounter BEFORE removing old mob so CheckStatus stays stable
        new_mob.current_encounter = E
        new_mob.atb_gauge = user.atb_gauge
        new_mob.atb_wait  = user.atb_wait
        E.enemies += new_mob
        E.all_participants += new_mob

        // 3. HP carry — preserve percentage from old form
        if(src.carry_hp && user.max_hp > 0)
            var/pct = user.hp / user.max_hp
            new_mob.hp = max(1, round(new_mob.max_hp * pct))

        // 4. Remove old mob from encounter lists (leave all_participants for the del sweep)
        E.enemies -= user
        E.players -= user
        E.all_participants -= user

        // 5. War cry from the new form
        if(hascall(new_mob, "Bark")) new_mob.Bark("war_cry")

        // 6. Deferred deletion — lets the current timeline finish before the datum is gone
        spawn(0) del(user)

// ============================================================
// Guardian Event — spawns an NPC that intercepts all hits aimed at the summoner.
// Both damage AND non-AOE heals/buffs aimed at the summoner route through the guardian.
// ============================================================
datum/skill_event/guardian
    var/npc_id = ""

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!E || !src.npc_id) return
        var/mob/enemy/guard = npc_factory.SpawnNPC(src.npc_id)
        if(!guard) return
        guard.current_encounter = E
        guard.atb_wait = guard.CalculateATBWait()
        if(user in E.players) E.players += guard
        else E.enemies += guard
        E.all_participants += guard
        if(!guard.temp_triggers_used) guard.temp_triggers_used = list()
        // Register guardian protection
        E.guardians[user] = guard
        world << "<i>[user.name] calls forth a guardian!</i>"
        guard.SendSignal(SIG_JOIN_BATTLE)
        guard.SendSignal(SIG_BIRTH)

// ============================================================
// Prism Event — spawns an NPC that imprisons a target enemy.
// The trapped mob cannot act or be targeted until the prism is destroyed.
// ============================================================
datum/skill_event/prism
    var/npc_id = ""

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!E || !src.npc_id || !target) return
        var/mob/enemy/prison_mob = npc_factory.SpawnNPC(src.npc_id)
        if(!prison_mob) return
        prison_mob.current_encounter = E
        prison_mob.atb_wait = prison_mob.CalculateATBWait()
        // Join the user's side (the prism is on the caster's team)
        if(user in E.players) E.players += prison_mob
        else E.enemies += prison_mob
        E.all_participants += prison_mob
        if(!prison_mob.temp_triggers_used) prison_mob.temp_triggers_used = list()
        // Imprison the target
        target.is_imprisoned = 1
        E.prisons[target] = prison_mob
        world << "<i>[target.name] has been imprisoned in a [prison_mob.name]!</i>"
        prison_mob.SendSignal(SIG_JOIN_BATTLE)
        prison_mob.SendSignal(SIG_BIRTH)

// ============================================================
// Shield Summon Event — spawns an NPC that intercepts damage-only hits on a target ally.
// Heals and buffs still reach the protected ally; AOE attacks bypass the shield.
// ============================================================
datum/skill_event/shield_summon
    var/npc_id = ""

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!E || !src.npc_id || !target) return
        var/mob/enemy/shield_mob = npc_factory.SpawnNPC(src.npc_id)
        if(!shield_mob) return
        shield_mob.current_encounter = E
        shield_mob.atb_wait = shield_mob.CalculateATBWait()
        if(user in E.players) E.players += shield_mob
        else E.enemies += shield_mob
        E.all_participants += shield_mob
        if(!shield_mob.temp_triggers_used) shield_mob.temp_triggers_used = list()
        // Register shield protection
        E.shields[target] = shield_mob
        world << "<i>[shield_mob.name] stands guard over [target.name]!</i>"
        shield_mob.SendSignal(SIG_JOIN_BATTLE)
        shield_mob.SendSignal(SIG_BIRTH)

// ============================================================
// Step 18: Backup Event
// Summons one or more NPC allies into the encounter mid-battle.
// ============================================================
datum/skill_event/backup
    var/npc_id = ""
    var/count  = 1

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!E || !src.npc_id) return
        var/i = 0
        while(i < src.count)
            var/mob/enemy/ally = npc_factory.SpawnNPC(src.npc_id)
            if(!ally) break
            ally.current_encounter = E
            ally.atb_wait = ally.CalculateATBWait()
            // Join the same side as the skill user
            if(user in E.players)
                E.players += ally
            else
                E.enemies += ally
            E.all_participants += ally
            // Reset trigger tracking for the new participant
            if(!ally.temp_triggers_used) ally.temp_triggers_used = list()
            // Announce and fire JoinBattle passives
            world << "<i>[ally.name] joins the battle!</i>"
            ally.SendSignal(SIG_JOIN_BATTLE)
            i++

/**
 * Scan Event — reveals target information to the caster (HP%, attribute, weakness, active statuses)
 */
datum/skill_event/scan
    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target || !user) return
        var/hp_pct = round((target.hp / max(1, target.max_hp)) * 100)
        var/attr = ("attribute" in target.vars && target.attribute != "") ? target.attribute : "None"

        user << "<b>=== [target.name] ===</b>"
        user << "HP: [hp_pct]% | Attribute: [attr]"

        // List active statuses
        var/list/status_names = list()
        for(var/datum/component/status/C in target.components)
            status_names += "[C.name] ([C.duration] turns)"
        if(status_names.len)
            user << "Active Effects: [jointext(status_names, ", ")]"
        else
            user << "Active Effects: None"

        // Check elemental weakness via element_factory
        if(attr != "None" && attr != "")
            var/list/weak_list = list()
            for(var/elem_id in element_factory.loaded_elements)
                var/mult = element_factory.GetMultiplier(elem_id, attr)
                if(mult > 1.0) weak_list += elem_id
            if(weak_list.len)
                user << "<font color='#FF4444'>Weak to: [jointext(weak_list, ", ")]</font>"
            else
                user << "No elemental weakness detected."
        user << "<b>==================</b>"

/**
 * Dispel Event — removes the most recently applied positive buff from the target
 */
datum/skill_event/dispel
    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!target) return
        var/datum/component/status/newest_buff = null
        for(var/datum/component/status/C in target.components)
            var/is_buff = 0
            if(C.stat_amount > 0) is_buff = 1
            if(C.hot_amount > 0) is_buff = 1
            if(C.hot_mp > 0) is_buff = 1
            if(C.dodge_chance > 0) is_buff = 1
            if(C.reraise) is_buff = 1
            if(C.damage_dealt_mult > 1.0) is_buff = 1
            if(C.provoke) is_buff = 1
            if(C.vanish) is_buff = 1
            if(is_buff) newest_buff = C  // Keep overwriting — last one in list is newest
        if(newest_buff)
            world << "<i>[newest_buff.name] was dispelled from [target.name]!</i>"
            if(hascall(target, "RemoveStatus"))
                target.RemoveStatus(newest_buff)
        else
            world << "<i>[target.name] has no buffs to dispel.</i>"

/**
 * Remove Status Event — removes a specific status from the target (or caster if target_self=1)
 */
datum/skill_event/remove_status
    var/status_id = ""
    var/target_self = 0  // If 1, removes from caster instead of target

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        var/mob/victim = src.target_self ? user : target
        if(!victim) return
        if(!hascall(victim, "GetStatus")) return
        var/datum/component/status/existing = victim.GetStatus(src.status_id)
        if(existing)
            victim.RemoveStatus(existing)