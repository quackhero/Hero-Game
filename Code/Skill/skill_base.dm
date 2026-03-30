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
    var/list/passive_stat_pct_mods = null  // Percentage-based stat mods: list("base_strength" = 0.10)

    // --- Modular Passive Tags (any passive can use these via JSON) ---

    // Bonus damage when target has a specific status
    var/passive_dmg_vs_status = ""        // Status ID (e.g. "blinded")
    var/passive_dmg_vs_status_pct = 0.0   // Bonus (e.g. 0.20 = +20%)

    // Bonus damage when target has BOTH of two status families
    var/list/passive_dmg_vs_dual_status_a = null  // First family IDs (any match)
    var/list/passive_dmg_vs_dual_status_b = null  // Second family IDs (any match)
    var/passive_dmg_vs_dual_status_pct = 0.0

    // Bonus damage on elemental weakness hits
    var/passive_weakness_bonus_pct = 0.0  // e.g. 0.20 = +20%

    // Bonus damage after defending (consumed on next qualifying attack)
    var/passive_defend_empower_pct = 0.0          // e.g. 0.25 = +25%
    var/passive_defend_empower_category = ""       // "Spell", "Attack", "" = any

    // Consecutive hit damage stacking
    var/passive_momentum_pct = 0.0   // Per-stack bonus (e.g. 0.05 = +5%)
    var/passive_momentum_max = 0     // Max stacks (e.g. 4)

    // Counter stance persists (not consumed after one trigger)
    var/passive_counter_persist = 0

    // Dodge cap upgrade
    var/passive_dodge_cap = 0    // If > 0, sets dodge_cap to this value

    // Flat dodge bonus
    var/passive_dodge_bonus = 0  // Added to dodge_bonus

    // Survive fatal blow (once per battle)
    var/passive_survive_fatal = 0
    var/passive_survive_fatal_overkill = 0  // If 0, doesn't trigger on overkill

    // Random target flag
    var/random_target = 0  // If 1, each hit_pass picks a new random enemy

    // Ambush requirement
    var/req_ambush = 0  // Target must not have acted OR user must not have attacked them

    var/hitrate = 100      // Percentage chance the skill hits. Rolled BEFORE timeline processing.
    var/charge_time = 0    // Delay in ticks BEFORE the skill timeline begins. 0 = instant.

    var/list/combo_branches = null
    
    var/list/req_target_name = null
    var/list/req_target_race = null
    var/req_target_hp = 0
    var/list/req_target_status = null
    var/list/req_user_status = null
    var/req_weapon_type = ""     // e.g. "Sword" — if set, user must have this weapon type equipped
    var/list/req_weapon_types = null  // List of acceptable weapon types (e.g. list("Sword", "Axe"))
    var/req_accessory_type = ""  // e.g. "Shield" — checks equipped_accessory.weapon_type
    var/list/req_target_or_user_status = null  // OR-based: target has X OR user has Y
    var/req_ally_name = ""       // Step 11: named ally must be alive in the encounter
    var/req_skill_id  = ""       // Step 12: this skill ID must be in user's equipped_skills

    var/list/event_timeline = list()
    var/uninterrupt_level = 0

    // Positional targeting: which states this skill can reach.
    // 0 (default) is treated as POS_GROUND only.
    // Use POS_AERIAL, POS_BURROWED, or POS_ANY for broader coverage.
    var/position_flags = 0

    var/dodgeable = 0     // If 1, target may dodge this skill via the DEX contest
    var/on_target_death = "STOP"
    var/aftermsg = ""    // Step 9: printed after all events complete (supports (I)/(E) substitution)

    // --- Jump ---
    var/is_jump = 0      // If 1, caster becomes Airborne during the skill and can hit aerial targets

    // --- Multi-hit ---
    var/hit_count = 1    // Number of times the full event timeline repeats

    // --- ForEvery AOE ---
    var/for_every = 0    // If 1 and target is an AOE list, afterlink fires once per hit target individually

    // --- Counter Stance ---
    var/is_counter_stance = 0  // If 1, this skill opens a counter window instead of attacking
    var/counter_window = 50    // Duration in ticks of the counter window

    // --- Overtime AOE ---
    var/overtime = 0           // Number of times the AOE timeline repeats after the first hit
    var/overtime_wait = 10     // Ticks between each overtime repetition

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

        // OR-based status requirement: target has X OR user has Y
        if(src.req_target_or_user_status)
            var/has_either = 0
            if(src.req_target_or_user_status["target"])
                for(var/sid in src.req_target_or_user_status["target"])
                    if(target && hascall(target, "HasStatus") && target.HasStatus(sid))
                        has_either = 1
                        break
            if(!has_either && src.req_target_or_user_status["user"])
                for(var/sid in src.req_target_or_user_status["user"])
                    if(user && hascall(user, "HasStatus") && user.HasStatus(sid))
                        has_either = 1
                        break
            if(!has_either) return 0

        // Ambush: target hasn't acted this encounter OR user hasn't attacked them
        if(src.req_ambush)
            var/target_hasnt_acted = ("has_acted_this_encounter" in target.vars) ? !target.has_acted_this_encounter : 0
            var/user_hasnt_hit = 1
            if(user && ("attacked_targets" in user.vars) && user.attacked_targets)
                if(target in user.attacked_targets) user_hasnt_hit = 0
            if(!target_hasnt_acted && !user_hasnt_hit) return 0

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

        // List-based weapon type requirement (Sword OR Axe)
        if(src.req_weapon_types && src.req_weapon_types.len)
            var/equipped_w = ("equipped_weapon" in user.vars) ? user.equipped_weapon : null
            var/wtype = equipped_w ? (equipped_w:weapon_type) : ""
            if(!(wtype in src.req_weapon_types))
                user << "<b>[src.name] requires one of: [jointext(src.req_weapon_types, ", ")]!</b>"
                user.EndTurn()
                return

        // Accessory type requirement (e.g. Shield)
        if(src.req_accessory_type != "")
            var/equipped_acc = ("equipped_accessory" in user.vars) ? user.equipped_accessory : null
            var/atype = equipped_acc ? (equipped_acc:weapon_type) : ""
            if(atype != src.req_accessory_type)
                user << "<b>[src.name] requires a [src.req_accessory_type] equipped!</b>"
                user.EndTurn()
                return

        // Step 11: named ally must be alive in the current encounter
        if(src.req_ally_name != "")
            var/ally_found = 0
            if(user.current_encounter)
                for(var/mob/A in user.current_encounter.GetAllies(user))
                    if(A.name == src.req_ally_name && !A.is_dead)
                        ally_found = 1
                        break
            if(!ally_found)
                user << "<b>[src.name] requires [src.req_ally_name] to be alive!</b>"
                user.EndTurn()
                return

        // Step 12: required skill must be equipped
        if(src.req_skill_id != "")
            var/skill_found = 0
            for(var/datum/skill/SK in user.equipped_skills)
                if(SK.id == src.req_skill_id) { skill_found = 1; break }
            if(!skill_found)
                user << "<b>[src.name] requires [src.req_skill_id] to be equipped!</b>"
                user.EndTurn()
                return

        user.is_busy = 1
        src.PayCost(user)

        // Hit rate check — rolled after MP is consumed but before effects resolve
        if(src.hitrate < 100)
            if(!prob(src.hitrate))
                world << "<i>[user.name]'s [src.name] missed!</i>"
                user.is_busy = 0
                if(hascall(user, "EndTurn")) user.EndTurn()
                return

        // Jump: apply Ascend status so the caster is Airborne during execution
        if(src.is_jump)
            if(hascall(user, "ApplyStatus"))
                user.ApplyStatus("ascended", 99, 0)
            world << "<i>[user.name] leaps into the air!</i>"

        // Counter Stance: open a counter window instead of (or in addition to) the timeline
        if(src.is_counter_stance && src.afterlink)
            var/datum/skill/counter_skill = skill_factory.loaded_skills[src.afterlink]
            if(counter_skill)
                var/datum/counter_window/CW = new()
                CW.owner = user
                CW.counter_skill = counter_skill
                CW.ticks_remaining = src.counter_window
                if(!user.active_counter_windows) user.active_counter_windows = list()
                user.active_counter_windows += CW
                // Tick-down loop
                var/datum/counter_window/cw_ref = CW
                var/datum/encounter/enc_ref = E
                spawn(0)
                    while(cw_ref && cw_ref.owner && (enc_ref ? enc_ref.is_active : 1))
                        sleep(2)
                        if(!cw_ref || !cw_ref.owner) break
                        cw_ref.Tick()

        src.ProcessTimeline(user, target, E)

    proc/ProcessTimeline(mob/user, target, datum/encounter/E, is_reaction = 0)
        // Capture the caster's positional state at the moment the skill begins.
        // Used to detect state changes during channeling (delays between events).
        var/cast_state = hascall(user, "GetPositionalState") ? user.GetPositionalState() : ""

        spawn(0)
            // --- CHARGE TIME ---
            if(src.charge_time > 0 && !is_reaction)
                world << "<i>[user.name] begins charging [src.name]...</i>"
                sleep(src.charge_time)

                // Check if caster is still alive and able to act
                if(user.hp <= user.death_threshold)
                    world << "<i>[user.name]'s [src.name] was interrupted!</i>"
                    user.is_busy = 0
                    if(hascall(user, "EndTurn")) user.EndTurn()
                    return

                // Check for positional interruption
                if(src.uninterrupt_level == SKILL_UNINTERRUPT_NONE)
                    if(cast_state && hascall(user, "GetPositionalState"))
                        var/current_state = user.GetPositionalState()
                        if(current_state != cast_state)
                            world << "<i><font color='#FFAA00'>[user.name]'s [src.name] was interrupted!</font></i>"
                            user.is_busy = 0
                            if(hascall(user, "EndTurn")) user.EndTurn()
                            return

                world << "<b>[user.name]'s [src.name] fires!</b>"

            // ---- Multi-hit outer loop ----
            // hit_count defaults to 1, so single-hit skills are unaffected.
            var/hit_pass = 0
            while(hit_pass < src.hit_count)
                hit_pass++

                // Between repetitions: short pause and re-validate target
                if(hit_pass > 1)
                    sleep(3)
                    if(user.hp <= user.death_threshold) break
                    if(!islist(target))
                        var/mob/check_t = target
                        if(check_t && check_t.hp <= check_t.death_threshold && !src.can_target_dead)
                            if(src.on_target_death == "STOP") break
                            else if(src.on_target_death == "RETARGET")
                                var/list/alive_en = list()
                                if(E)
                                    for(var/mob/en in E.GetEnemies(user))
                                        if(en.hp > 0) alive_en += en
                                if(alive_en.len) target = pick(alive_en)
                                else break

                // Random target: pick a new random enemy each hit
                if(src.random_target && !islist(target) && E)
                    var/list/alive_targets = list()
                    for(var/mob/rt in E.GetEnemies(user))
                        if(!rt.is_dead && rt.hp > rt.death_threshold)
                            if(user.CanTarget(rt, src, 1))
                                alive_targets += rt
                    if(alive_targets.len)
                        target = pick(alive_targets)
                    else
                        break

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
                                    // Jump interrupted: land the caster
                                    if(src.is_jump)
                                        var/datum/component/status/asc_i = hascall(user, "GetStatus") ? user.GetStatus("ascended") : null
                                        if(asc_i) user.RemoveStatus(asc_i)
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
                                // Step 10: TARGET_MARKED — skip unmarked mobs in the AOE list
                                if((src.targeting_flags & TARGET_MARKED) && !T.is_marked) continue
                                EV.Run(user, T, src, E)
                    else
                        EV.Run(user, target, src, E)

            // ---- Jump landing ----
            if(src.is_jump)
                var/datum/component/status/asc_land = hascall(user, "GetStatus") ? user.GetStatus("ascended") : null
                if(asc_land) user.RemoveStatus(asc_land)
                world << "<i>[user.name] lands.</i>"

            // Step 9: aftermsg — displayed after all events finish, before afterlink/combos
            if(src.aftermsg != "")
                var/after = src.aftermsg
                after = replacetext(after, "(I)",    user.name)
                after = replacetext(after, "(user)", user.name)
                if(!islist(target))
                    var/mob/aftertarg = target
                    if(aftertarg)
                        after = replacetext(after, "(E)",      aftertarg.name)
                        after = replacetext(after, "(enemy)",  aftertarg.name)
                        after = replacetext(after, "(target)", aftertarg.name)
                world << "<i>[after]</i>"

            if(src.final_attack)
                world << "<b>[user.name] sacrifices themselves!</b>"
                user.hp = 0
                user.ClampStats()
                user.CheckDeath()

            // --- THE REACTION EXIT ---
            if(is_reaction)
                return

            // ---- Overtime AOE: repeat the timeline in the background ----
            if(src.overtime > 0 && islist(target))
                var/list/ot_target = target
                var/datum/skill/ot_skill = src
                var/mob/ot_user = user
                var/datum/encounter/ot_e = E
                spawn(0)
                    var/repeats_left = ot_skill.overtime
                    while(repeats_left > 0 && ot_e && ot_e.is_active)
                        sleep(ot_skill.overtime_wait)
                        repeats_left--
                        var/list/still_valid = list()
                        for(var/mob/T in ot_target)
                            if(!T.is_dead && T.hp > T.death_threshold)
                                still_valid += T
                        if(!still_valid.len) break
                        for(var/datum/skill_event/EV in ot_skill.event_timeline)
                            if(EV.is_global)
                                EV.Run(ot_user, still_valid[1], ot_skill, ot_e)
                            else
                                for(var/mob/T in still_valid)
                                    EV.Run(ot_user, T, ot_skill, ot_e)

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

            // --- Skill Chaining (afterlink / ForEvery) ---
            if(src.afterlink && !src.is_counter_stance)
                var/datum/skill/next_skill = skill_factory.loaded_skills[src.afterlink]

                if(next_skill)
                    // ForEvery: if target is an AOE list, fire afterlink against each alive mob
                    if(src.for_every && islist(target))
                        for(var/mob/T in target)
                            if(!T.is_dead && T.hp > T.death_threshold)
                                next_skill.ProcessTimeline(user, T, E)
                                sleep(2)
                    else
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