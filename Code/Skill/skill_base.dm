datum/skill
    var/name = ""
    var/cost = 0
    var/targeting_flags = 0 // Uses the Bitflags from _Defines.dm
    var/list/MsgList = list()   
    var/list/DmgList = list()   
    var/list/EfctList = list()  
    var/damage_type = "Physical"
    var/trigger_condition = "" 
    var/trigger_chance = 100   
    var/is_temp = 0
    var/charge_time = 0
    var/required_hp_percent = 0
    var/targeting_mode = "Target" 
    
    var/list/components = list()
    var/list/event_timeline = list()
    
    var/uninterrupt_level = SKILL_UNINTERRUPT_NONE
    var/is_processing = 0
    
    proc/CanTrigger(mob/user, passed_val)
        if(!prob(src.trigger_chance)) return 0

        if(src.required_hp_percent > 0)
            var/hp_percent = (user.hp / user.max_hp) * 100
            if(hp_percent > src.required_hp_percent) return 0
        return 1

    proc/Execute(mob/user, target, datum/encounter/E)
        if(src.is_processing) return
        
        if(user.mp < src.cost)
            user << "Not enough MP!"
            return

        user.mp -= src.cost
        src.is_processing = 1
        src.ProcessTimeline(user, target, E)

    proc/ProcessTimeline(mob/user, target, datum/encounter/E)
        spawn(0)
            for(var/datum/skill_event/EV in src.event_timeline)
                if(src.uninterrupt_level < SKILL_UNINTERRUPT_DEATH && user.hp <= 0)
                    break
                
                if(EV.delay > 0)
                    sleep(EV.delay)
                
                // --- AOE & GLOBAL LOGIC ---
                if(islist(target))
                    if(EV.is_global)
                        // If it's a global message, only run it once!
                        EV.Run(user, target[1], src, E)
                    else
                        // If it's damage/healing, loop through everyone!
                        for(var/mob/T in target)
                            EV.Run(user, T, src, E)
                else
                    EV.Run(user, target, src, E)


            src.Complete(user)

    proc/Complete(mob/user)
        src.is_processing = 0
        user.EndTurn()

    proc/ExecuteStep(mob/user, mob/target, step_data)
        if(istext(step_data))
            user << "[step_data]"
            if(target && target != user)
                target << "[user] [step_data]"
        else if(ispath(step_data, /datum/skill_event))
            var/datum/skill_event/E = new step_data
            E.Run(user, target, src, user.current_encounter)

// ============================================================
// THE EVENT OBJECTS 
// ============================================================

datum/skill_event
    var/delay = 0 
    var/is_global = 0 // <--- This flag tells the engine "Run me only once!"
    
    proc/Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        return