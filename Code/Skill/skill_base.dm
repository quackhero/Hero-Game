datum/skill
    var/name = ""
    var/cost = 0
    var/targeting_flags = 0 
    var/damage_type = "Physical"

    var/category = "Attack" // "Attack", "Spell", "Item", etc.
    var/trigger_category = "Any" // Filter for passive counters
    
    // --- Trigger/Counter Support ---
    var/trigger_condition = "" 
    var/trigger_chance = 100
    var/targeting_mode = "Target" 

    var/can_target_dead = 0
    var/hp_cost = 0
    var/ammo_type = ""
    var/ammo_cost = 0
    var/fizzle_chance = 0
    var/final_attack = 0
    var/afterlink = ""

    var/is_passive = 0
    var/list/passive_stat_mods = null

    var/list/combo_branches = null
    
    var/list/req_target_name = null 
    var/list/req_target_race = null 
    var/req_target_hp = 0           
    var/list/req_target_status = null 
    var/list/req_user_status = null   

    var/list/event_timeline = list()
    var/uninterrupt_level = 0

    var/on_target_death = "STOP"

    // --- Filter Logic ---
    proc/ExecuteStep(mob/user, mob/target, step_data)
        if(istext(step_data))
            world << "[step_data]" 
        else if(ispath(step_data, /datum/skill_event))
            var/datum/skill_event/E = new step_data
            E.Run(user, target, src, user.current_encounter)

    proc/IsValidTarget(mob/user, mob/target)
        if(!target) return 0
        if(!src.can_target_dead && target.hp <= 0) return 0
        if((src.targeting_flags & TARGET_REVIVE) && !(src.targeting_flags & TARGET_HEAL) && !target.is_dead) return 0
        if(src.req_target_name && !(target.name in src.req_target_name)) return 0
        if(src.req_target_race && !(target.vars["race"] in src.req_target_race)) return 0
        if(src.req_target_hp != 0)
            var/hp_pct = (target.hp / max(1, target.max_hp)) * 100
            if(src.req_target_hp > 0 && hp_pct < src.req_target_hp) return 0 
            if(src.req_target_hp < 0 && hp_pct > abs(src.req_target_hp)) return 0 

        if(src.req_target_status && hascall(target, "HasStatus"))
            var/has_req = 0
            for(var/status_id in src.req_target_status)
                if(target.HasStatus(status_id)) { has_req = 1; break }
            if(!has_req) return 0 

        if(src.req_user_status && user && hascall(user, "HasStatus"))
            var/has_req = 0
            for(var/status_id in src.req_user_status)
                if(user.HasStatus(status_id)) { has_req = 1; break }
            if(!has_req) return 0
            
        return 1

    proc/PayCost(mob/user)
        if(src.cost > 0) user.mp -= src.cost
        if(src.hp_cost > 0) user.hp -= src.hp_cost
        if(src.ammo_type && src.ammo_cost > 0)
            user.ConsumeAmmo(src.ammo_type, src.ammo_cost)
        user.ClampStats()

    proc/Execute(mob/user, target, datum/encounter/E)
        if(src.fizzle_chance > 0 && prob(src.fizzle_chance))
            user.is_busy = 0 
            user.EndTurn()
            return

        user.is_busy = 1
        src.PayCost(user)
        src.ProcessTimeline(user, target, E)

    // --- FIXED: Indented properly inside datum/skill ---
    proc/ProcessTimeline(mob/user, target, datum/encounter/E, is_reaction = 0)
        spawn(0)
            for(var/datum/skill_event/EV in src.event_timeline)
                if(user.hp <= 0) break 
                
                if(EV.delay > 0) sleep(EV.delay)
                
                // --- The Target Death Check ---
                if(!islist(target)) 
                    var/mob/T = target
                    // Bypass death check if the skill can target dead bodies
                    if(T && T.hp <= 0 && !src.can_target_dead) 
                        if(src.on_target_death == "STOP")
                            break // End the timeline immediately
                            
                        else if(src.on_target_death == "RETARGET")
                            var/list/alive_enemies = list()
                            for(var/mob/enemy in E.GetEnemies(user))
                                if(enemy.hp > 0) alive_enemies += enemy
                                
                            if(alive_enemies.len > 0)
                                target = pick(alive_enemies)
                                world << "<i>[user.name] redirects to [(target:name)]!</i>"
                            else
                                break // No enemies left to retarget, end combat/skill early
                                
                // --- Run the Event (FIXED formatting to remove empty else warning) ---
                if(islist(target))
                    if(EV.is_global) 
                        EV.Run(user, target[1], src, E)
                    else 
                        for(var/mob/T in target) 
                            EV.Run(user, T, src, E)
                else 
                    EV.Run(user, target, src, E)

            if(src.final_attack)
                world << "<b>[user.name] sacrifices themselves!</b>"
                user.hp = 0
                user.ClampStats()

            // --- THE REACTION EXIT ---
            if(is_reaction)
                return

            // --- INTERACTIVE COMBO BRANCHES ---
            if(src.combo_branches && src.combo_branches.len > 0)
                if(ismob(user) && user:client)
                    // 1. Remember the target(s)
                    if(islist(target)) user:active_combo_targets = target
                    else user:active_combo_targets = list(target)
                    
                    // 2. Open the prompt menu
                    user:UpdateBattleMenu(E, "Combo_Select", src)
                    
                    // 3. HALT EXECUTION! Do not call EndTurn() yet!
                    return

            // --- Skill Chaining (afterlink) ---
            if(src.afterlink)
                var/datum/skill/next_skill = skill_factory.loaded_skills[src.afterlink]

                if(next_skill)
                    next_skill.ProcessTimeline(user, target, E)
                    return
                else
                    world.log << "ERROR: Skill [src.name] tried to afterlink to '[src.afterlink]', but it doesn't exist!"

            // If there is no afterlink, OR the afterlink failed to load, end the turn safely.
            user.is_busy = 0
            if(hascall(user, "EndTurn"))
                user.EndTurn()

// ============================================================
// THE EVENT BASE DEFINITION
// ============================================================
datum/skill_event
    var/delay = 0 
    var/is_global = 0 
    
    proc/Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        return