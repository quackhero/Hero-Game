datum/skill
    var/id   = "" // JSON factory key (e.g. "basic_attack"). Empty = hardcoded DM skill.
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
    var/trigger_once = 0      // If 1, can only fire once per battle (tracked via temp_triggers_used)
    var/list/passive_stat_mods = null

    var/list/combo_branches = null
    
    var/list/req_target_name = null
    var/list/req_target_race = null
    var/req_target_hp = 0
    var/list/req_target_status = null
    var/list/req_user_status = null
    var/req_weapon_type = ""  // e.g. "Sword" — if set, user must have this weapon type equipped

    var/list/event_timeline = list()
    var/uninterrupt_level = 0

    // Positional targeting: which states this skill can reach.
    // 0 (default) is treated as POS_GROUND only.
    // Use POS_AERIAL, POS_BURROWED, or POS_ANY for broader coverage.
    var/position_flags = 0

    var/dodgeable = 0     // If 1, target may dodge this skill via the DEX contest
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
        if(!src.can_target_dead && target.hp <= target.death_threshold) return 0
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

        // Mute: cannot use any skill except basic_attack
        if(src.id != "basic_attack" && hascall(user, "HasDisableType") && user.HasDisableType("skills"))
            user << "<b>You are Muted and cannot use skills!</b>"
            user.EndTurn()
            return

        // Weapon type requirement: block the skill if the user doesn't have the right weapon
        if(src.req_weapon_type)
            var/equipped_w = ("equipped_weapon" in user.vars) ? user.equipped_weapon : null
            var/wtype = equipped_w ? (equipped_w:weapon_type) : ""
            if(wtype != src.req_weapon_type)
                user << "<b>[src.name] requires a [src.req_weapon_type] equipped!</b>"
                user.EndTurn()
                return

        user.is_busy = 1
        src.PayCost(user)
        src.ProcessTimeline(user, target, E)

    proc/ProcessTimeline(mob/user, target, datum/encounter/E, is_reaction = 0)
        // Capture the caster's positional state at the moment the skill begins.
        // Used to detect state changes during channeling (delays between events).
        var/cast_state = hascall(user, "GetPositionalState") ? user.GetPositionalState() : ""

        spawn(0)
            for(var/datum/skill_event/EV in src.event_timeline)
                if(user.hp <= user.death_threshold) break

                if(EV.delay > 0)
                    sleep(EV.delay)

                    // --- Channeling Interrupt Check ---
                    // Only fires after an event with delay > 0, since that is the only window
                    // in which the caster's state could have changed between events.
                    if(cast_state && hascall(user, "GetPositionalState"))
                        var/current_state = user.GetPositionalState()
                        if(current_state != cast_state)
                            if(src.uninterrupt_level == SKILL_UNINTERRUPT_NONE)
                                // Interruptible skill: abort the remaining timeline.
                                world << "<i><font color='#FFAA00'>[user.name]'s [src.name] was interrupted by a positional state change!</font></i>"
                                user.is_busy = 0
                                if(hascall(user, "EndTurn")) user.EndTurn()
                                return

                            else
                                // Uninterruptible: skill still fires, but targeting is re-evaluated
                                // against the caster's new state. Update cast_state so subsequent
                                // delay checks compare from the new baseline.
                                cast_state = current_state
                                // Rebuild AOE target list from the full encounter pool so that
                                // targets newly reachable from the caster's new state are included,
                                // not just remaining targets from the original list.
                                if(islist(target) && E)
                                    var/list/pool = (src.targeting_flags & (TARGET_HEAL | TARGET_REVIVE)) ? E.GetAllies(user) : E.GetEnemies(user)
                                    var/list/rebuilt = list()
                                    for(var/mob/M in pool)
                                        if(!M.is_dead && M.hp > M.death_threshold)
                                            if(user.CanTarget(M, src, 1) && src.IsValidTarget(user, M))
                                                rebuilt += M
                                    target = rebuilt

                // --- Target Death Check ---
                if(!islist(target))
                    var/mob/T = target
                    if(T && T.hp <= T.death_threshold && !src.can_target_dead)
                        if(src.on_target_death == "STOP")
                            break

                        else if(src.on_target_death == "RETARGET")
                            var/list/alive_enemies = list()
                            for(var/mob/enemy in E.GetEnemies(user))
                                if(enemy.hp > 0) alive_enemies += enemy

                            if(alive_enemies.len > 0)
                                target = pick(alive_enemies)
                                world << "<i>[user.name] redirects to [(target:name)]!</i>"
                            else
                                break

                // --- Run the Event ---
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

                    // 3. Spawn a safety timeout — if the player doesn't pick a branch
                    //    within 10 seconds, auto-end their turn to prevent soft-locks.
                    var/combo_snapshot = user.turn_id
                    spawn(100)
                        if(user && user.turn_id == combo_snapshot && user.is_busy && user.active_combo_targets)
                            world << "<i>[user.name]'s combo window has closed!</i>"
                            user << browse(null, "window=battle_menu")
                            user.active_combo_targets = null
                            user.EndTurn()

                    // 4. HALT EXECUTION! Do not call EndTurn() yet!
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