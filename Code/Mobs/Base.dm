mob
    // ============================================================
    // 1. CORE STATS
    // ============================================================
    var/hp = 100
    var/max_hp = 100
    var/mp = 50
    var/max_mp = 50
    var/strength = 10
    var/dexterity = 10
    var/intelligence = 10
    var/mind = 10
    var/resilience = 10
    var/vitality = 10
    var/race = "Human"
    var/combat_flags = 0
    var/turn_id = 0
    var/list/active_counters = list()
    
    var/atb_gauge = 0      
    var/is_busy = 0        
    var/is_dead = 0
    var/defending = 0
    var/max_skill_slots = 4
    var/list/equipped_skills = list()

    var/list/active_combo_targets = null // Remembers who we are combo-ing!

    mob/enemy
        var/base_exp = 50

    var/max_item_slots = 3
    var/list/equipped_items = list()
    
    var/death_threshold = 0 // Berserkers can set this to -50
    var/is_downed = 0

    var/list/skills = list()          
    var/list/trigger_skills = list()
    var/list/components = list()      

    var/mob/last_attacker
    var/datum/encounter/current_encounter

    // ============================================================
    // 2. GUARD RAILS
    // ============================================================
    
    proc/CanAct(datum/skill/S = null)
        if(src.is_dead || src.hp <= src.death_threshold) return 0
        
        if(S)
            // 1. Check MP
            if(src.mp < S.cost) 
                src << "Not enough MP!"
                return 0
            
            // 2. Check HP (Ensures they don't kill themselves to cast)
            if(S.hp_cost > 0 && src.hp <= S.hp_cost)
                src << "Not enough HP to use this!"
                return 0
                
            // 3. Check Ammo
            if(S.ammo_type && !src.HasAmmo(S.ammo_type, S.ammo_cost))
                src << "Not enough [S.ammo_type]s equipped!"
                return 0
                
        return 1

    proc/CanTarget(mob/T)
        if(!T || T.is_dead) 
            src << "Target is invalid!"
            return 0
        if(T.current_encounter != src.current_encounter) return 0
        return 1

    proc/ClampStats()
        src.hp = min(src.hp, src.max_hp) // No floor, allows negative
        src.mp = max(0, min(src.mp, src.max_mp))

        if(src.hp <= 0 && !src.is_downed)
            src.is_downed = 1
            src.SendSignal("SIG_DOWNED")

        if(src.hp <= src.death_threshold && !src.is_dead)
            src.HandleDeath(src.last_attacker)

    // Call this explicitly from revive skills — never runs automatically.
    proc/Revive(heal_amount = 1)
        if(!src.is_dead) return
        src.is_dead = 0
        src.is_downed = 0
        src.hp = max(heal_amount, 1)
        src.ClampStats()
        world << "<i><font color='#00FF00'>[src.name] has been revived!</font></i>"

    proc/SendSignal(signal_id, passed_val = 0)
        if(signal_id == "SIG_DAMAGED" && ismob(passed_val))
            src.last_attacker = passed_val

        for(var/datum/skill/S in src.trigger_skills)
            if(S.trigger_condition == signal_id)
                if(prob(S.trigger_chance))
                    var/mob/targ = (S.targeting_mode == "Ref-Target") ? src.last_attacker : src
                    spawn() S.Execute(src, targ, src.current_encounter, passed_val)

        // Fire equipped passive skills that match this signal
        for(var/datum/skill/S in src.equipped_skills)
            if(!S.is_passive) continue
            if(S.trigger_condition == signal_id)
                if(prob(S.trigger_chance))
                    var/mob/targ = (S.targeting_mode == "Ref-Target") ? src.last_attacker : src
                    spawn() S.ProcessTimeline(src, targ, src.current_encounter, 1)

    // ============================================================
    // 3. TURN INTERFACE
    // ============================================================
    
    proc/ReadyTurn()
        for(var/datum/component/C in src.components)
            C.OnTurnStart(src)
        
        if(!src.CanAct())
            if(src.hp <= src.death_threshold)
                src.EndTurn()
            return

        if(src.HasStatus("stunned"))
            world << "<i><font color='#CCCC00'>[src.name] is stunned and loses their turn!</font></i>"
            src.EndTurn() // Instantly aborts the turn and resets the ATB gauge!
            return

        var/datum/encounter/E = src.current_encounter
        src.SendSignal("ON_TURN_START")
        src.TakeAction(E)

    proc/TakeAction(datum/encounter/E)
        if(!src.CanAct()) return
        src.defending = 0 

        if(src.client)
            spawn(0)
                var/action = input(src, "Action Selection", "Battle") in list("Attack", "Guard", "Pass")
                if(!src.CanAct()) return 
                
                switch(action)
                    if("Attack")
                        var/list/enemies = E.GetEnemies(src)
                        if(!enemies.len) { src.EndTurn(); return }
                        var/mob/T = input(src, "Target?") in enemies + "Cancel"
                        if(T == "Cancel") src.TakeAction(E)
                        else if(src.CanTarget(T)) src.BasicAttack(T)
                    if("Guard")
                        src.defending = 1
                        world << "<i>[src.name] braces for impact!</i>"
                        src.EndTurn()
                    if("Pass")
                        src.EndTurn()
        else
            // AI Simple Logic
            sleep(5) 
            var/list/enemies = E.GetEnemies(src)
            if(enemies.len)
                var/mob/T = pick(enemies)
                src.BasicAttack(T)
            else src.EndTurn()

    proc/EndTurn()
        for(var/datum/component/C in src.components)
            C.OnTurnEnd(src)
        
        src.atb_gauge = 0
        src.is_busy = 0
        src.SendSignal("ON_TURN_END")

    proc/BasicAttack(mob/target)
        if(!src.CanAct() || !src.CanTarget(target)) return src.EndTurn()
        
        // --- CE2 UPGRADE ---
        // Route basic attacks through the JSON engine!
        var/datum/skill/attack_skill = skill_factory.loaded_skills["basic_attack"]
        
        if(attack_skill)
            attack_skill.Execute(src, target, src.current_encounter)
        else
            // Fallback just in case you forgot to add it to the JSON
            var/dmg = max(1, src.strength - target.resilience)
            target.TakeDamage(dmg, src, "Physical")
            src.EndTurn()
    
    proc/TakeDamage(amount, mob/attacker, damage_type = "Physical", silent = 0)
        if(src.is_dead) return
        var/final_amount = round(amount)
        src.hp -= final_amount
        
        if(!silent)
            var/hp_info = (src.hp <= 0) ? " ([src.hp] HP)" : ""
            if(attacker)
                world << "<b>[attacker.name]</b> attacks <b>[src.name]</b>! ([final_amount] Damage)[hp_info]"
            else
                world << "<b>[src.name]</b> takes [final_amount] damage![hp_info]"
            
        src.SendSignal("SIG_DAMAGED", attacker)
        src.ClampStats()

    proc/HandleDeath(mob/killer)
        if(src.is_dead) return
        src.is_dead = 1
        src.atb_gauge = 0
        src.is_busy = 0
        world << "<b>*** [src.name] has been defeated! ***</b>"
        if(src.current_encounter) src.current_encounter.CheckStatus()

    proc/ApplyStatus(status_id, duration, amount)
        // 1. Grab the template from the factory
        var/datum/component/status/template = status_factory.loaded_statuses[status_id]
        if(!template)
            world.log << "ERROR: Tried to apply unknown status: [status_id]"
            return

        // 2. Check if they already have it
        var/datum/component/status/existing = src.GetStatus(status_id)
        if(existing)
            existing.OnRefresh(duration, amount)
        else
            // 3. Clone the template and apply it!
            var/datum/component/status/new_status = template.Clone()
            new_status.owner = src
            new_status.duration = duration
            new_status.amount = amount
            src.components += new_status

            new_status.OnApply(src) // Apply the status effects immediately
            
            world << "<i><font color='#B19CD9'>[src.name] gains [new_status.name]!</font></i>"

    proc/GetStatus(status_id)
        for(var/datum/component/status/C in src.components)
            if(C.id == status_id) return C
        return null

    proc/HasStatus(status_id)
        if(src.GetStatus(status_id)) return 1
        return 0

    // --- NEW: Ammo Management Procs ---
    proc/HasAmmo(req_name, req_amount)
        for(var/datum/item/consumable/I in src.equipped_items)
            if(lowertext(I.name) == lowertext(req_name))
                if(I.amount >= req_amount) return 1
        return 0

    proc/ConsumeAmmo(req_name, req_amount)
        for(var/datum/item/consumable/I in src.equipped_items)
            if(lowertext(I.name) == lowertext(req_name))
                I.amount -= req_amount
                if(I.amount <= 0)
                    src.equipped_items -= I
                    if(src.vars["inventory"]) src.inventory -= I // Remove from bag too!
                return 1
        return 0

    proc/RemoveStatus(datum/component/status/S)
        src.components -= S
        S.OnRemove(src)
        world << "<i><font color='#B19CD9'>[src.name]'s [S.name] wore off!</font></i>"
        del(S)
