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
    var/turn_id = 0
    
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
    var/is_vanished = 0        // Set by Vanish status: mob cannot be targeted at all
    var/is_aerial_target = 0   // Set by Ascend/Float: mob is an aerial target
    var/is_burrowed = 0        // Set by Dig/Burrow status: mob is underground

    var/channel_start_state = "" // Positional state stored when channeling begins

    var/list/skills = list()
    var/list/trigger_skills = list()
    var/list/components = list()
    var/list/gear_granted_skills = list() // Skills/passives added by equipped gear (managed by UpdateStats)      

    var/mob/last_attacker
    var/mob/last_target           // The last mob this mob attacked/hit
    var/list/temp_triggers_used   // Tracks trigger_once skills fired this battle
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

    // Returns "Airborne", "Burrowed", or "Grounded" based on active flags.
    proc/GetPositionalState()
        if(src.is_aerial_target) return "Airborne"
        if(src.is_burrowed) return "Burrowed"
        return "Grounded"

    // Optional skill param enables positional filtering.
    // Pass silent=1 when building UI target lists to suppress error messages.
    proc/CanTarget(mob/T, datum/skill/S = null, silent = 0)
        if(!T || T.is_dead)
            if(!silent) src << "Target is invalid!"
            return 0
        if(T.current_encounter != src.current_encounter) return 0
        if(T.is_vanished)
            if(!silent) src << "[T.name] cannot be targeted right now!"
            return 0

        // --- Positional state check ---
        // Grounded targets can always be reached by any skill (default).
        // Airborne targets require: caster is also Airborne, OR skill has POS_AERIAL.
        // Burrowed targets require: caster is also Burrowed, OR skill has POS_BURROWED.
        var/target_state = T.GetPositionalState()
        if(target_state == "Airborne")
            if(!src.is_aerial_target)
                var/skill_pos = S ? S.position_flags : POS_GROUND
                if(!(skill_pos & POS_AERIAL))
                    if(!silent) src << "[T.name] is airborne and cannot be reached!"
                    return 0
        else if(target_state == "Burrowed")
            if(!src.is_burrowed)
                var/skill_pos = S ? S.position_flags : POS_GROUND
                if(!(skill_pos & POS_BURROWED))
                    if(!silent) src << "[T.name] is burrowed underground!"
                    return 0

        return 1

    // Returns the first full-disable status component (Freeze, Petrify, Sleep, Stop, etc.)
    proc/HasFullDisable()
        for(var/datum/component/status/C in src.components)
            if(C.full_disable) return C
        return null

    // Returns 1 if the mob has a status that blocks the given action type
    proc/HasDisableType(dtype)
        for(var/datum/component/status/C in src.components)
            if(C.disable_type == dtype) return 1
        return 0

    // Applies healing, converting it to damage if the mob is Zombified
    proc/ApplyHeal(amount, mob/healer)
        if(amount <= 0) return
        for(var/datum/component/status/C in src.components)
            if(C.zombie_mode)
                src << "<font color='#00AA00'><b>[src.name] is Zombified — healing deals damage instead!</b></font>"
                src.TakeDamage(amount, healer, "True", 0)
                return
        src.hp += amount
        src.ClampStats()

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

        if(!src.temp_triggers_used) src.temp_triggers_used = list()

        for(var/datum/skill/S in src.trigger_skills)
            if(S.trigger_condition == signal_id)
                if(S.trigger_once && S.id && (S.id in src.temp_triggers_used)) continue
                if(prob(S.trigger_chance))
                    if(S.trigger_once && S.id) src.temp_triggers_used += S.id
                    var/mob/targ = (S.targeting_mode == "Ref-Target") ? src.last_attacker : src
                    spawn() S.Execute(src, targ, src.current_encounter)

        // Fire equipped passive skills that match this signal
        for(var/datum/skill/S in src.equipped_skills)
            if(!S.is_passive) continue
            if(S.trigger_condition == signal_id)
                if(S.trigger_once && S.id && (S.id in src.temp_triggers_used)) continue
                if(prob(S.trigger_chance))
                    if(S.trigger_once && S.id) src.temp_triggers_used += S.id
                    var/mob/targ = (S.targeting_mode == "Ref-Target") ? src.last_attacker : src
                    spawn() S.ProcessTimeline(src, targ, src.current_encounter, 1)

        // Fire OnSignal on all active components (Re-Raise, etc.)
        for(var/datum/component/C in src.components)
            C.OnSignal(signal_id, passed_val)

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

        // Full Disable: Freeze, Petrify, Sleep, Stop, Captured, Entangled, etc.
        var/datum/component/status/disable_status = src.HasFullDisable()
        if(disable_status)
            world << "<i><font color='#CCCC00'>[src.name] is [disable_status.name] and cannot act!</font></i>"
            src.EndTurn()
            return

        // Probabilistic skip: Paralysis / Tired / Fatigue
        for(var/datum/component/status/C in src.components)
            if(C.skip_chance > 0 && prob(C.skip_chance))
                world << "<i><font color='#CCAA00'>[src.name] is [C.name] and loses their turn!</font></i>"
                src.EndTurn()
                return

        var/datum/encounter/E = src.current_encounter
        src.SendSignal("ON_TURN_START")

        // --- HP-based turn-start signals ---
        if(src.max_hp > 0)
            var/hp_pct = (src.hp / src.max_hp) * 100
            if(hp_pct < 30)
                src.SendSignal("SIG_HURT")
            if(src.hp >= src.max_hp)
                src.SendSignal("SIG_FULL_HP") // Use trigger_once=1 on skill for the "temp" variant

        // --- Alone signal: fires when all other allies are incapacitated ---
        if(E)
            var/allies_alive = 0
            for(var/mob/A in E.GetAllies(src))
                if(A != src && !A.is_dead && A.hp > A.death_threshold)
                    allies_alive++
            if(!allies_alive)
                src.SendSignal("SIG_ALONE")

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
                        src.SendSignal("SIG_WAIT")
                        src.EndTurn()
                    if("Pass")
                        src.SendSignal("SIG_WAIT")
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
        if(!src.CanAct()) return src.EndTurn()

        // Fear: cannot use basic attacks
        if(src.HasDisableType("attack"))
            src << "<b>You are Feared and cannot attack!</b>"
            src.EndTurn()
            return

        // Confusion: may redirect attack to a random ally or self
        for(var/datum/component/status/C in src.components)
            if(C.confusion > 0 && prob(C.confusion))
                var/datum/encounter/CE = src.current_encounter
                var/list/confusion_targets = CE ? CE.GetAllies(src) : list()
                if(!confusion_targets.len) confusion_targets += src
                target = pick(confusion_targets)
                world << "<i><font color='#FF8800'>[src.name] is Confused and attacks [target.name]!</font></i>"
                break

        // Blind: chance for the attack to miss entirely
        for(var/datum/component/status/C in src.components)
            if(C.miss_chance > 0 && prob(C.miss_chance))
                world << "<i>[src.name]'s attack missed!</i>"
                src.EndTurn()
                return

        // Route basic attacks through the JSON engine so we can pass the skill to CanTarget.
        var/datum/skill/attack_skill = skill_factory.loaded_skills["basic_attack"]
        if(!src.CanTarget(target, attack_skill)) return src.EndTurn()

        // --- Weapon Attack Message ---
        // If the equipped weapon defines attack_messages, pick one at random and display
        // it as flavor text before the skill's own damage events fire.
        if("equipped_weapon" in src.vars && src.equipped_weapon)
            var/datum/item/equipment/W = src.equipped_weapon
            if(W.attack_messages && W.attack_messages.len > 0)
                var/msg = pick(W.attack_messages)
                msg = replacetext(msg, "(I)",      src.name)
                msg = replacetext(msg, "(user)",   src.name)
                msg = replacetext(msg, "(target)", target.name)
                msg = replacetext(msg, "(E)",      target.name)
                world << "<b>[msg]</b>"

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

        // Run component BeforeDamage hooks (shields, invincibility, mana shield, shatter, etc.)
        for(var/datum/component/C in src.components)
            if(C && (C in src.components))
                final_amount = C.OnBeforeDamage(final_amount, damage_type, attacker)

        if(final_amount <= 0) return // All damage was absorbed/negated

        src.hp -= final_amount
        
        if(!silent)
            var/hp_info = (src.hp <= 0) ? " ([src.hp] HP)" : ""
            if(attacker)
                world << "<b>[attacker.name]</b> attacks <b>[src.name]</b>! ([final_amount] Damage)[hp_info]"
            else
                world << "<b>[src.name]</b> takes [final_amount] damage![hp_info]"
            
        src.SendSignal("SIG_DAMAGED", attacker)

        if(attacker && attacker != src)
            attacker.last_target = src
            attacker.SendSignal("SIG_DEALT_DAMAGE", final_amount)

        src.ClampStats()

    proc/HandleDeath(mob/killer)
        if(src.is_dead) return
        src.SendSignal("SIG_DYING", killer) // Before is_dead: Re-Raise OnSignal restores HP here

        // Re-Raise: if a component restored HP during SIG_DYING, abort death
        if(src.hp > src.death_threshold)
            src.is_downed = 0
            return

        src.is_dead = 1
        src.atb_gauge = 0
        src.is_busy = 0
        src.SendSignal("SIG_DEATH", killer) // After is_dead: death confirmation
        world << "<b>*** [src.name] has been defeated! ***</b>"
        if(killer && killer != src)
            killer.SendSignal("SIG_KILL", src) // Fires on the killer, passing the defeated mob
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
            src.SendSignal("SIG_STATUS_APPLIED", status_id)

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
        var/sid = S.id // Save before del()
        src.components -= S
        S.OnRemove(src)
        world << "<i><font color='#B19CD9'>[src.name]'s [S.name] wore off!</font></i>"
        del(S)
        src.SendSignal("SIG_STATUS_REMOVED", sid)
