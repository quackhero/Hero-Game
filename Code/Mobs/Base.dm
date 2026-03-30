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
    var/attribute = ""     // Elemental identity used by the damage pipeline ("Fire","Ice", etc.)
    var/turn_id = 0
    
    var/atb_gauge = 0      // Legacy display var — no longer drives CombatLoop
    var/atb_wait = 0       // Countdown ticks until this mob's next turn
    var/total_weight = 0   // Sum of equipped gear weight (updated by ComputeTotalWeight)
    var/dodge_bonus = 0    // Flat bonus to effective dodge DEX (e.g. from passives)
    var/dodge_cap = BASE_DODGE_CAP  // Max dodge % this mob can achieve
    var/is_busy = 0
    var/is_dead = 0
    var/defending = 0
    var/max_skill_slots = 4
    var/list/equipped_skills = list()

    var/list/active_combo_targets = null    // Remembers who we are combo-ing!
    var/list/active_counter_windows = null  // Active counter stance windows (datum/counter_window)

    mob/enemy
        var/base_exp = 50

    var/max_item_slots = 3
    var/list/equipped_items = list()
    
    var/death_threshold = 0 // Berserkers can set this to -50
    var/is_downed = 0
    var/is_vanished = 0        // Set by Vanish status: mob cannot be targeted at all
    var/is_aerial_target = 0   // Set by Ascend/Float: mob is an aerial target
    var/is_burrowed = 0        // Set by Dig/Burrow status: mob is underground
    var/is_marked = 0          // Set by the mark skill event; TARGET_MARKED AOE only hits marked mobs
    var/is_imprisoned = 0      // Set by the prism skill event; imprisoned mob cannot act or be targeted

    var/pending_death = 0          // Set by TakeDamage when HP <= threshold; processed by damage event
    var/mob/pending_death_killer   // The mob that dealt the killing blow

    var/channel_start_state = "" // Positional state stored when channeling begins
    var/override_attack_damage_type = "" // Computed by BasicAttack; read by the damage event to apply weapon subtype/element

    var/list/skills = list()
    var/list/trigger_skills = list()
    var/list/components = list()
    var/list/gear_granted_skills = list() // Skills/passives added by equipped gear (managed by UpdateStats)      

    var/mob/last_attacker
    var/mob/last_target           // The last mob this mob attacked/hit
    var/list/temp_triggers_used   // Tracks trigger_once skills fired this battle

    var/momentum_stacks = 0
    var/last_element_used = ""
    var/is_concentrated = 0
    var/list/attacked_targets = null
    var/has_acted_this_encounter = 0
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
        // Imprisoned mobs (trapped in a Prism) cannot be targeted by anyone
        if(T.is_imprisoned)
            if(!silent) src << "[T.name] is imprisoned and cannot be targeted!"
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
                src.ProcessPendingDeath()
                return
        // Misfortune: enemies with 3+ debuffs receive reduced healing
        if(src.current_encounter)
            var/debuff_count = 0
            for(var/datum/component/status/C in src.components)
                if(C.dot_amount > 0 || C.stat_amount < 0 || C.full_disable || C.skip_chance > 0 || C.miss_chance > 0 || C.disable_type != "" || C.sap_mp > 0 || C.confusion > 0 || C.damage_resist_pct < 0)
                    debuff_count++
            if(debuff_count >= 3)
                for(var/mob/opp in src.current_encounter.GetEnemies(src))
                    if(opp.is_dead) continue
                    for(var/datum/skill/P in opp.equipped_skills)
                        if(P.is_passive && P.id == "oracle_misfortune")
                            amount = round(amount * 0.70)
                            break
        src.hp += amount
        src.ClampStats()

    proc/ClampStats()
        src.hp = min(src.hp, src.max_hp) // No floor, allows negative
        src.mp = max(0, min(src.mp, src.max_mp))

        if(src.hp <= 0 && !src.is_downed)
            src.is_downed = 1
            src.SendSignal("SIG_DOWNED")

        // Death is NO LONGER triggered here automatically.
        // TakeDamage defers death so damage messages print first.
        // Non-TakeDamage HP reductions must call CheckDeath() explicitly.

    // For non-TakeDamage HP reductions (DoT, environmental, debug).
    // Checks if this mob should die and processes death immediately.
    proc/CheckDeath()
        if(src.hp <= src.death_threshold && !src.is_dead)
            src.HandleDeath(src.last_attacker)

    // Processes a pending death that was deferred by TakeDamage.
    // Called by the damage event AFTER it prints its flavor message.
    proc/ProcessPendingDeath()
        if(!src.pending_death) return
        src.pending_death = 0
        var/mob/killer = src.pending_death_killer
        src.pending_death_killer = null
        src.HandleDeath(killer)

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

        // Imprisoned mobs skip their turn silently
        if(src.is_imprisoned)
            src.EndTurn()
            return

        // Full Disable: Freeze, Petrify, Sleep, Stop, Captured, Entangled, etc.
        var/datum/component/status/disable_status = src.HasFullDisable()
        if(disable_status)
            world << "<i><font color='#CCCC00'>[src.name] is [disable_status.name] and cannot act!</font></i>"
            src.momentum_stacks = 0
            src.EndTurn()
            return

        // Probabilistic skip: Paralysis / Tired / Fatigue
        for(var/datum/component/status/C in src.components)
            if(C.skip_chance > 0 && prob(C.skip_chance))
                world << "<i><font color='#CCAA00'>[src.name] is [C.name] and loses their turn!</font></i>"
                src.momentum_stacks = 0
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
                        src.momentum_stacks = 0
                        for(var/datum/skill/P in src.equipped_skills)
                            if(P.is_passive && P.passive_defend_empower_pct != 0)
                                src.is_concentrated = 1
                                break
                        world << "<i>[src.name] braces for impact!</i>"
                        src.SendSignal("SIG_WAIT")
                        src.EndTurn()
                    if("Pass")
                        src.momentum_stacks = 0
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

        src.has_acted_this_encounter = 1
        src.is_busy = 0
        src.ComputeTotalWeight()
        src.atb_wait = src.CalculateATBWait()
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

        // --- NPC Attack Message (fallback when no equipped weapon or weapon has no messages) ---
        else if(("attack_messages" in src.vars) && src:attack_messages && length(src:attack_messages))
            var/msg = pick(src:attack_messages)
            msg = replacetext(msg, "(I)",      src.name)
            msg = replacetext(msg, "(user)",   src.name)
            msg = replacetext(msg, "(target)", target.name)
            msg = replacetext(msg, "(E)",      target.name)
            world << "<b>[msg]</b>"

        // Compute the effective damage type from the equipped weapon.
        // Combines physical subtype + elemental tag into a single string, e.g. "Slashing Fire".
        // Stored on the mob so the damage event can read it without changing the event system.
        var/weapon_dmg_type = "Physical"
        if("equipped_weapon" in src.vars && src.equipped_weapon)
            var/datum/item/equipment/W = src.equipped_weapon
            var/wdt = (W.damage_type && W.damage_type != "") ? W.damage_type : "Physical"
            weapon_dmg_type = wdt
            if(W.elemental_tag && W.elemental_tag != "")
                weapon_dmg_type = "[wdt] [W.elemental_tag]"
        src.override_attack_damage_type = weapon_dmg_type

        // Step 4: SIG_PRE_ATTACK fires just before the attack executes
        src.SendSignal(SIG_PRE_ATTACK, target)

        if(attack_skill)
            attack_skill.Execute(src, target, src.current_encounter)
        else
            // Fallback just in case you forgot to add it to the JSON
            var/dmg = max(1, src.strength - target.resilience)
            target.TakeDamage(dmg, src, weapon_dmg_type)
            src.EndTurn()

        // Step 4: SIG_POST_ATTACK fires after the Execute() call returns
        // Note: Execute() uses spawn() internally, so this fires at the point of dispatch
        src.SendSignal(SIG_POST_ATTACK, target)
    
    // ============================================================
    // TakeDamage — full damage pipeline entry point
    //
    // Parameters:
    //   amount      — raw incoming damage (before resilience, elemental, affinity)
    //   attacker    — the mob dealing the damage (null for environmental/DoT)
    //   damage_type — string describing damage: "Physical", "Fire", "Slashing Fire",
    //                 "True" (bypasses everything), etc.
    //   silent      — if 1, suppress the standard "takes X damage" message.
    //                 Elemental context messages (WEAK/RESIST/NULL/ABSORB) always show.
    //   bypass      — passed to DamageContext; -1 ignores resilience entirely,
    //                 > 0 reduces effective resilience by that amount.
    //
    // Returns the final HP damage applied (0 if nulled or absorbed).
    // ============================================================
    proc/TakeDamage(amount, mob/attacker, damage_type = "Physical", silent = 0, bypass = 0)
        if(src.is_dead) return 0
        var/final_amount = round(amount)

        // ---- Phase 1: Legacy OnBeforeDamage hooks ----
        // Handles shields, invincibility, mana shield, shatter, break-on-hit, and
        // the old damage_resist_type/damage_resist_pct fields on status components.
        // These run before the new pipeline so existing statuses remain fully functional.
        for(var/datum/component/C in src.components)
            if(C && (C in src.components))
                final_amount = C.OnBeforeDamage(final_amount, damage_type, attacker)

        if(final_amount <= 0) return 0  // All damage absorbed/negated by legacy hooks

        // ---- Phase 2: Parse damage_type into physical and elemental tokens ----
        // "Slashing Fire" → physical="Slashing", elemental="Fire"
        // "Fire"          → physical="", elemental="Fire"
        // "Slashing"      → physical="Slashing", elemental=""
        // "Physical"      → physical="Physical", elemental=""
        // "True"          → is_true_damage=1 (handled inside ResolveDamage)
        var/parsed_physical  = ""
        var/parsed_elemental = ""
        var/list/phys_set = list("Slashing", "Piercing", "Blunt", "Physical")
        if(damage_type != "True")
            var/list/tokens = splittext(damage_type, " ")
            for(var/tok in tokens)
                if(tok in phys_set)
                    parsed_physical = tok
                else
                    parsed_elemental = tok

        // ---- Phase 3: Build DamageContext and run the full pipeline ----
        var/datum/damage_context/DC = new()
        DC.attacker      = attacker
        DC.defender      = src
        DC.base_damage   = final_amount
        DC.physical_type  = parsed_physical
        DC.elemental_type = parsed_elemental
        DC.is_true_damage = (damage_type == "True") ? 1 : 0
        DC.bypass        = bypass

        DC.ResolveDamage()

        // ---- Phase 4: Handle Absorb ----
        if(DC.was_absorbed)
            var/elem_color = (DC.elemental_type != "") ? element_factory.GetColor(DC.elemental_type) : "#00FF00"
            world << "<font color='[elem_color]'><b>[src.name] absorbed the attack!</b></font>"
            src.ApplyHeal(DC.base_damage, attacker)
            src.SendSignal("SIG_DAMAGED", attacker)
            if(attacker && attacker != src)
                attacker.last_target = src
                attacker.SendSignal("SIG_DEALT_DAMAGE", 0)
            return 0

        // ---- Phase 5: Handle Null ----
        if(DC.was_nulled)
            world << "<font color='#FFFFFF'><b>[src.name] is immune!</b></font>"
            src.SendSignal("SIG_DAMAGED", attacker)
            if(attacker && attacker != src)
                attacker.last_target = src
                attacker.SendSignal("SIG_DEALT_DAMAGE", 0)
            return 0

        // ---- Phase 6: Apply final damage to HP ----
        src.hp -= DC.final_damage

        // ---- Phase 7: Battle log messages ----
        // Defending message (always shown so the player understands the halving).
        if(DC.defender.defending && DC.final_damage > 0)
            world << "<i>[src.name] mitigates the attack!</i>"
            src.SendSignal(SIG_DEFEND_BLOCK, DC.pre_defend_damage)

        // Elemental weakness (always shown; contains the fully resolved damage number).
        if(DC.hit_weakness)
            var/wk_color = element_factory.GetColor(DC.elemental_type)
            var/type_lbl = DC.elemental_type
            world << "<font color='[wk_color]'><b>WEAK! [DC.final_damage] [type_lbl] damage!</b></font>"

        // Affinity resist (always shown).
        else if(DC.hit_resist)
            var/type_lbl = (DC.elemental_type != "") ? DC.elemental_type : ((DC.physical_type != "") ? DC.physical_type : damage_type)
            world << "<font color='#AAAAAA'>Resisted! [DC.final_damage] [type_lbl] damage.</font>"

        // Standard message for callers that did not show their own (silent=0).
        else if(!silent)
            var/hp_info = (src.hp <= 0) ? " ([src.hp] HP)" : ""
            if(attacker)
                world << "<b>[attacker.name]</b> attacks <b>[src.name]</b>! ([DC.final_damage] Damage)[hp_info]"
            else
                world << "<b>[src.name]</b> takes [DC.final_damage] damage![hp_info]"

        // ---- Phase 8: Signals and post-damage hooks ----
        src.SendSignal("SIG_DAMAGED", attacker)

        // Step 5: Element-filtered victim signal — e.g. "SIG_DAMAGED_BY_FIRE"
        // Passives with trigger_condition == "SIG_DAMAGED_BY_FIRE" match exactly.
        if(damage_type && damage_type != "")
            src.SendSignal("SIG_DAMAGED_BY_[uppertext(damage_type)]", attacker)

        if(DC.final_damage >= (src.max_hp * 0.25))
            if(hascall(src, "Bark")) src:Bark("hurt")

        if(attacker && attacker != src)
            attacker.last_target = src
            attacker.SendSignal("SIG_DEALT_DAMAGE", DC.final_damage)

            // Step 5: Element-filtered attacker signal — e.g. "SIG_DEALT_FIRE_DAMAGE"
            if(damage_type && damage_type != "")
                attacker.SendSignal("SIG_DEALT_[uppertext(damage_type)]_DAMAGE", DC.final_damage)

        // Step 6: Zero-damage signals — fires when pipeline reduced HP damage to 0
        // (won't fire for absorb/null hits since those return early above)
        if(DC.final_damage <= 0)
            src.SendSignal(SIG_TOOK_ZERO_DAMAGE, attacker)
            if(attacker && attacker != src)
                attacker.SendSignal(SIG_DEALT_ZERO_DAMAGE, src)

        // ---- Phase 9: Counter Window check ----
        // If the victim has active counter windows, trigger one against the attacker.
        if(src.active_counter_windows && src.active_counter_windows.len && attacker && attacker != src)
            for(var/datum/counter_window/CW in src.active_counter_windows.Copy())
                CW.OnHit(attacker)
                break  // only one counter fires per hit

        src.ClampStats()

        // Defer death — let the damage event print its message first
        if(src.hp <= src.death_threshold && !src.is_dead && !src.pending_death)
            src.pending_death = 1
            src.pending_death_killer = attacker

        return DC.final_damage

    proc/HandleDeath(mob/killer)
        if(src.is_dead) return

        // Passive survive fatal blow (modular)
        for(var/datum/skill/S in src.equipped_skills)
            if(!S.is_passive || !S.passive_survive_fatal) continue
            if(!S.passive_survive_fatal_overkill && src.hp <= -(src.max_hp)) continue
            if(!src.temp_triggers_used) src.temp_triggers_used = list()
            if(S.id in src.temp_triggers_used) continue
            src.temp_triggers_used += S.id
            src.hp = 1
            src.is_downed = 0
            world << "<b><font color='#FFD700'>[src.name] clings to life!</font></b>"
            return

        src.SendSignal("SIG_DYING", killer) // Before is_dead: Re-Raise OnSignal restores HP here

        // Re-Raise: if a component restored HP during SIG_DYING, abort death
        if(src.hp > src.death_threshold)
            src.is_downed = 0
            return

        src.is_dead = 1
        src.atb_gauge = 0
        src.is_busy = 0
        src.SendSignal("SIG_DEATH", killer) // After is_dead: death confirmation
        // Death bark first (the enemy's death cry), then the defeat announcement
        if(hascall(src, "Bark")) src:Bark("death")
        world << "<b>*** [src.name] has been defeated! ***</b>"
        if(killer && killer != src)
            killer.SendSignal("SIG_KILL", src) // Fires on the killer, passing the defeated mob
            if(hascall(killer, "Bark")) killer:Bark("kill")
        // Guardian/Shield/Prison cleanup: remove this mob from encounter tracking lists
        var/datum/encounter/CE = src.current_encounter
        if(CE)
            // Remove from guardians (this mob was a guardian protecting someone)
            for(var/mob/protected in CE.guardians)
                if(CE.guardians[protected] == src)
                    CE.guardians.Remove(protected)
                    world << "<i>The guardian protecting [protected.name] has fallen!</i>"
                    break
            // Remove from shields
            for(var/mob/shielded in CE.shields)
                if(CE.shields[shielded] == src)
                    CE.shields.Remove(shielded)
                    world << "<i>The shield protecting [shielded.name] has been destroyed!</i>"
                    break
            // Remove from prisons — free the trapped mob
            for(var/mob/trapped in CE.prisons)
                if(CE.prisons[trapped] == src)
                    CE.prisons.Remove(trapped)
                    if("is_imprisoned" in trapped.vars) trapped.is_imprisoned = 0
                    world << "<i>[trapped.name] has been freed from imprisonment!</i>"
                    break
            CE.CheckStatus()

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
            world << "<i><font color='#B19CD9'>[src.name] ([existing.name] [existing.duration]/[existing.max_duration] refreshed)</font></i>"
        else
            // 3. Clone the template and apply it!
            var/datum/component/status/new_status = template.Clone()
            new_status.owner = src
            new_status.duration = duration
            new_status.max_duration = duration
            new_status.amount = amount
            src.components += new_status

            new_status.OnApply(src) // Apply the status effects immediately

            world << "<i><font color='#B19CD9'>[src.name] ([new_status.name] [new_status.duration]/[new_status.max_duration] inflicted)</font></i>"
            src.SendSignal("SIG_STATUS_APPLIED", status_id)
            src.SendSignal(SIG_ON_INFECT, new_status)  // Step 2: trigger passive infect reactions
            // Per-status targeted infect signal — e.g. "SIG_INFECTED_BY_POISONED"
            src.SendSignal("SIG_INFECTED_BY_[uppertext(new_status.id)]", new_status)

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

    proc/RemoveStatus(datum/component/status/S, silent = 0)
        var/sid = S.id // Save before del()
        src.components -= S
        S.OnRemove(src)
        if(!silent)
            world << "<i><font color='#B19CD9'>[src.name] ([S.name] has worn off!)</font></i>"
        src.SendSignal(SIG_ON_EXPIRE, S)   // Step 2: fire before del() so datum is still valid
        // Per-status targeted expire signal — e.g. "SIG_EXPIRED_SLEEPING"
        src.SendSignal("SIG_EXPIRED_[uppertext(sid)]", S)
        del(S)
        src.SendSignal("SIG_STATUS_REMOVED", sid)

    // ============================================================
    // WEIGHT & ATB WAIT PROCS
    // ============================================================

    // Sums the weight of all equipped gear pieces using the colon operator
    // so the proc works safely on any mob type (base or player).
    proc/ComputeTotalWeight()
        var/w = 0
        if("equipped_weapon" in src.vars && src:equipped_weapon)
            w += src:equipped_weapon:weight
        if("equipped_armor" in src.vars && src:equipped_armor)
            w += src:equipped_armor:weight
        if("equipped_accessory" in src.vars && src:equipped_accessory)
            w += src:equipped_accessory:weight
        src.total_weight = w

    // Returns DEX after subtracting the weight penalty, floored at 0.
    proc/GetEffectiveDodgeDEX()
        return max(0, src.dexterity + src.dodge_bonus - round(src.total_weight * WEIGHT_DODGE_FACTOR))

    // Returns the number of countdown ticks before this mob acts,
    // incorporating both DEX speed and weight penalty.
    proc/CalculateATBWait()
        var/wait = round(ATB_BASE_WAIT / (1 + src.dexterity * ATB_DEX_FACTOR))
        wait += round(src.total_weight * WEIGHT_ATB_FACTOR)
        return max(ATB_MIN_WAIT, min(wait, ATB_BASE_WAIT))

    // Computes dodge % for a DEX contest between src (defender) and attacker.
    // Adds any flat dodge_chance from active status components on top.
    proc/CalculateDodgeChance(mob/attacker)
        var/target_edex = src.GetEffectiveDodgeDEX()
        var/attacker_edex = max(1, attacker.GetEffectiveDodgeDEX())
        var/chance = round((target_edex / (target_edex + attacker_edex)) * src.dodge_cap)
        // Add flat dodge_chance from active status components (e.g. Time Stop)
        for(var/datum/component/status/C in src.components)
            if(C.dodge_chance > 0)
                chance += C.dodge_chance
        return min(chance, src.dodge_cap)
