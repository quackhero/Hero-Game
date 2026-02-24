datum/skill
    var/name = ""
    var/cost = 0
    var/targeting_flags = 0 
    var/damage_type = "Physical"
    
    // --- Add these back for Trigger/Counter support ---
    var/trigger_condition = "" 
    var/trigger_chance = 100
    var/targeting_mode = "Target" 

    var/can_target_dead = 0
    var/hp_cost = 0
    var/ammo_type = ""
    var/ammo_cost = 0
    var/fizzle_chance = 0
    var/final_attack = 0
    
    var/list/req_target_name = null 
    var/list/req_target_race = null 
    var/req_target_hp = 0           
    var/list/req_target_status = null 
    var/list/req_user_status = null   

    var/list/event_timeline = list()
    var/uninterrupt_level = 0

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
        // REMOVED: is_processing check. We handle turn-flow on the mob now.
        
        if(src.fizzle_chance > 0 && prob(src.fizzle_chance))
           // world << "<i>[user.name] attempts to use [src.name], but it fizzles out!</i>"
            user.EndTurn()
            return

        src.PayCost(user)
        src.ProcessTimeline(user, target, E)

    proc/ProcessTimeline(mob/user, target, datum/encounter/E)
        spawn(0)
            for(var/datum/skill_event/EV in src.event_timeline)
                if(user.hp <= 0) break // Stop if the user dies mid-skill
                
                if(EV.delay > 0)
                    sleep(EV.delay)
                
                if(islist(target))
                    if(EV.is_global)
                        EV.Run(user, target[1], src, E)
                    else
                        for(var/mob/T in target)
                            EV.Run(user, T, src, E)
                else
                    EV.Run(user, target, src, E)

            if(src.final_attack)
                world << "<b>[user.name] sacrifices themselves to unleash the attack!</b>"
                user.hp = 0
                user.ClampStats()

            // THE FIX: The Turn ends here once the timeline finishes.
            user.EndTurn()

// ============================================================
// THE EVENT BASE DEFINITION (REQUIRED FOR skill_events.dm)
// ============================================================
datum/skill_event
    var/delay = 0 
    var/is_global = 0 
    
    proc/Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        return