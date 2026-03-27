datum/component
    var/name = ""
    var/mob/owner // The mob this component is attached to
    var/duration = 0 // How long this lasts (for Status Effects)
    var/amount = 0

    // --- Damage Hooks (Existing) ---
    // Runs before damage is applied (Good for Shields)
    proc/OnBeforeDamage(damage, type, mob/attacker)
        return damage

    // Runs after damage is dealt (Good for Leech/Thorns)
    proc/OnAfterDamage(damage, type, mob/attacker)
        return

    // --- Signal Hooks (New) ---
    // Runs when the mob receives a signal (ON_HIT, ON_DEATH, etc.)
    proc/OnSignal(signal_id, passed_val)
        return

    // Runs at the start of the mob's turn (Regen, Poison)
    proc/OnTurnStart(mob/M)
        return

    // Runs at the end of the mob's turn (Tick down duration)
    proc/OnTurnEnd(mob/M)
        // Guard: component may have already been removed by RemoveStatus() earlier this tick
        if(!owner || !(src in owner.components)) return
        if(src.duration > 0)
            src.duration--
            if(src.duration <= 0)
                // Auto-delete when time is up
                if(M && hascall(M, "RemoveStatus"))
                    call(M, "RemoveStatus")(src)
                else
                    if(owner) owner.components -= src
                    del(src)

    proc/OnRefresh(new_duration, new_amount)
        src.duration = max(src.duration, new_duration)
        if(new_amount > src.amount)
            src.amount = new_amount

// --- Existing Leech Component ---
datum/component/leech
    var/leech_percent = 0

    New(percent)
        src.leech_percent = percent

    OnAfterDamage(damage, type, mob/attacker)
        if(!attacker || damage <= 0) return
        
        var/heal_amt = round(damage * src.leech_percent)
        if(heal_amt > 0)
            attacker.hp = min(attacker.max_hp, attacker.hp + heal_amt)
            attacker << "You leeched [heal_amt] HP!"

// ============================================================
// NEW: THE JSON STATUS COMPONENT
// ============================================================
datum/component/status
    var/id = "" // The JSON ID

    // --- OVERRIDES ---
    name = "Unknown Status"
    amount = 0
    duration = 0
    var/max_duration = 0  // Stores the original duration for display purposes (e.g. "3/5 turns")
    owner = null

    // --- Trigger Integration ---
    var/trigger_condition = ""
    var/trigger_chance = 100
    var/reaction_skill_id = ""
    var/trigger_category = "Any"

    // --- Damage Over Time ---
    var/dot_amount = 0
    var/dot_type = "Poison"
    var/dot_is_percent = 0       // If 1, dot_amount is a fraction of HP (e.g. 0.1 = 10%)
    var/dot_use_current = 0      // If 1, % uses current HP (Demi). Otherwise max HP (Burns)
    var/dot_cannot_kill = 0      // If 1, DoT cannot reduce HP below 1
    var/dot_delayed_burst = 0    // If 1, damage accumulates each turn then bursts (Parasite)
    var/dot_accumulated = 0      // Internal: stored burst damage
    var/stack_double = 0         // If 1, stacking this status doubles dot_amount (Wound)

    // --- Heal Over Time ---
    var/hot_amount = 0           // HP restored per turn
    var/hot_mp = 0               // MP restored per turn (Regen)

    // --- Primary Stat Modification ---
    var/stat_mod = ""            // "STR", "DEX", "RES", "INT", "MND", "VIT"
    var/stat_amount = 0          // Flat amount (or computed from stat_percent on apply)
    var/stat_percent = 0.0       // If nonzero, stat_amount = round(current_base_stat * stat_percent)

    // --- Second Stat Modification (e.g. Berserk: STR up + RES to 0) ---
    var/second_stat = ""
    var/second_stat_amount = 0
    var/second_stat_percent = 0.0

    // --- Crowd Control: Full Disable (mob loses their turn) ---
    var/full_disable = 0         // Petrify, Freeze, Sleep, Stop, Captured, Entangled
    var/shatter_mult = 1.0       // Damage multiplier when struck (Petrify=2.0, Freeze=1.5)
    var/shatter_type = ""        // Required damage type to shatter ("" = any, "Fire" = Freeze)
    var/break_on_hit = 0         // Status breaks when taking any damage (Sleep)

    // --- Probabilistic Turn Skip ---
    var/skip_chance = 0          // % chance to lose turn (Paralysis=30, Tired=40, Fatigue=50)

    // --- Partial Action Restrictions ---
    var/disable_type = ""        // "skills","attack","items","ultimate","w_skills","ally_target"

    // --- Blind / Miss ---
    var/miss_chance = 0          // % chance for this mob's attacks to miss

    // --- Charm / Dodge (defensive) ---
    var/dodge_chance = 0         // % chance to negate an incoming attack
    var/dodge_once = 0           // If 1, the status removes itself after the first successful dodge (Time Stop)

    // --- Confusion ---
    var/confusion = 0            // If > 0, this % chance redirects attacks to a random ally/self

    // --- MP Drain ---
    var/sap_mp = 0               // MP drained from owner each turn

    // --- Special Mechanics ---
    var/zombie_mode = 0          // Heals become damage instead
    var/reraise = 0              // Auto-revive on death (handled in HandleDeath via SIG_DYING)
    var/invincible_thresh = 0    // Blocks all damage below this value (9999 for Invincibility)
    var/mana_shield = 0          // Routes incoming damage to MP instead of HP
    var/kills_on_expire = 0      // If 1, triggers HandleDeath when this status expires (Death status)

    // --- Damage Modifiers ---
    var/damage_resist_type = ""  // Element for elemental shield ("Fire","Ice","Water","Lightning","Nova")
    var/damage_resist_pct = 0.0  // Fraction of matching damage blocked (0.5 = 50%)
    var/damage_dealt_mult = 0.0  // Multiplier applied to damage this mob deals (1.5=Boost, 0.5=Break)

    // --- Targeting Flags ---
    var/provoke = 0              // Signals enemy AI to focus this mob
    var/provoke_reverse = 0      // Signals enemy AI to avoid this mob (Minor status)
    var/vanish = 0               // Sets owner.is_vanished on apply/remove
    var/is_aerial = 0            // Sets owner.is_aerial_target on apply/remove
    var/is_burrowed = 0          // Sets owner.is_burrowed on apply/remove

    // --- Skill Granting ---
    var/list/granted_skill_ids = null     // Active skill IDs added to mob.skills while this status is active
    var/list/granted_passive_ids = null   // Passive skill IDs added to mob.equipped_skills while active
    var/list/status_granted_skills = null // Internal: tracks what was actually added (for cleanup on remove)
    var/lock_position = 0                 // If 1, this mob's positional state cannot be changed by other statuses

    // --- Mind Control ---
    var/mind_control = 0       // Step 14: swaps which encounter party this mob belongs to
    var/was_in_players = -1    // Internal: -1=unset, 1=was in players, 0=was in enemies

    // --- Equipment Removal ---
    var/remove_weapon    = 0   // If 1, strips equipped_weapon on apply
    var/remove_armor     = 0   // If 1, strips equipped_armor on apply
    var/remove_accessory = 0   // If 1, strips equipped_accessory on apply
    // Instance state — stores the stripped item so it can be restored on remove
    var/datum/item/equipment/stripped_item = null
    var/stripped_slot = ""     // "weapon", "armor", or "accessory"

    // ============================================================
    // --- THE CLONER ---
    // ============================================================
    proc/Clone()
        var/datum/component/status/S = new()
        S.id = src.id
        S.name = src.name
        S.max_duration = src.max_duration
        S.trigger_condition = src.trigger_condition
        S.trigger_chance = src.trigger_chance
        S.reaction_skill_id = src.reaction_skill_id
        S.trigger_category = src.trigger_category
        S.dot_amount = src.dot_amount
        S.dot_type = src.dot_type
        S.dot_is_percent = src.dot_is_percent
        S.dot_use_current = src.dot_use_current
        S.dot_cannot_kill = src.dot_cannot_kill
        S.dot_delayed_burst = src.dot_delayed_burst
        S.stack_double = src.stack_double
        S.hot_amount = src.hot_amount
        S.hot_mp = src.hot_mp
        S.stat_mod = src.stat_mod
        S.stat_amount = src.stat_amount
        S.stat_percent = src.stat_percent
        S.second_stat = src.second_stat
        S.second_stat_amount = src.second_stat_amount
        S.second_stat_percent = src.second_stat_percent
        S.full_disable = src.full_disable
        S.shatter_mult = src.shatter_mult
        S.shatter_type = src.shatter_type
        S.break_on_hit = src.break_on_hit
        S.skip_chance = src.skip_chance
        S.disable_type = src.disable_type
        S.miss_chance = src.miss_chance
        S.dodge_chance = src.dodge_chance
        S.dodge_once = src.dodge_once
        S.confusion = src.confusion
        S.sap_mp = src.sap_mp
        S.zombie_mode = src.zombie_mode
        S.reraise = src.reraise
        S.invincible_thresh = src.invincible_thresh
        S.mana_shield = src.mana_shield
        S.kills_on_expire = src.kills_on_expire
        S.damage_resist_type = src.damage_resist_type
        S.damage_resist_pct = src.damage_resist_pct
        S.damage_dealt_mult = src.damage_dealt_mult
        S.provoke = src.provoke
        S.provoke_reverse = src.provoke_reverse
        S.vanish = src.vanish
        S.is_aerial = src.is_aerial
        S.is_burrowed = src.is_burrowed
        S.granted_skill_ids = src.granted_skill_ids ? src.granted_skill_ids.Copy() : null
        S.granted_passive_ids = src.granted_passive_ids ? src.granted_passive_ids.Copy() : null
        S.lock_position = src.lock_position
        S.mind_control = src.mind_control
        S.remove_weapon    = src.remove_weapon
        S.remove_armor     = src.remove_armor
        S.remove_accessory = src.remove_accessory
        // Note: status_granted_skills, was_in_players, stripped_item, stripped_slot are instance state — not copied from template
        return S

    // ============================================================
    // --- APPLY / REMOVE ---
    // ============================================================
    proc/OnApply(mob/M)
        // 1. Primary stat mod (calculate from percent if needed)
        if(src.stat_mod)
            if(src.stat_amount == 0 && src.stat_percent != 0)
                src.stat_amount = src.ComputeStatPct(M, src.stat_mod, src.stat_percent)
            if(src.stat_amount != 0)
                src.ModifyStat(M, src.stat_mod, src.stat_amount)

        // 2. Second stat mod (Berserk: RES to 0)
        if(src.second_stat)
            if(src.second_stat_amount == 0 && src.second_stat_percent != 0)
                src.second_stat_amount = src.ComputeStatPct(M, src.second_stat, src.second_stat_percent)
            if(src.second_stat_amount != 0)
                src.ModifyStat(M, src.second_stat, src.second_stat_amount)

        // 3. Vanish flag
        if(src.vanish && ("is_vanished" in M.vars))
            M.is_vanished = 1

        // 4. Aerial flag — mutually exclusive with Burrowed
        if(src.is_aerial && ("is_aerial_target" in M.vars))
            // Check if any active status locks this mob's positional state
            var/pos_locked_aerial = 0
            for(var/datum/component/status/LC in M.components)
                if(LC != src && LC.lock_position) { pos_locked_aerial = 1; break }
            if(pos_locked_aerial)
                world << "<font color='#AAAAFF'><b>[M.name]'s position is locked — aerial state blocked!</b></font>"
            else
                // Remove any active Burrowed statuses first (states are mutually exclusive)
                if("is_burrowed" in M.vars && M.is_burrowed)
                    for(var/datum/component/status/C in M.components)
                        if(C != src && C.is_burrowed)
                            if(hascall(M, "RemoveStatus"))
                                call(M, "RemoveStatus")(C)
                            break
                M.is_aerial_target = 1

        // 5. Burrowed flag — mutually exclusive with Aerial
        if(src.is_burrowed && ("is_burrowed" in M.vars))
            // Check if any active status locks this mob's positional state
            var/pos_locked_burrowed = 0
            for(var/datum/component/status/LC in M.components)
                if(LC != src && LC.lock_position) { pos_locked_burrowed = 1; break }
            if(pos_locked_burrowed)
                world << "<font color='#AAAAFF'><b>[M.name]'s position is locked — burrowed state blocked!</b></font>"
            else
                // Remove any active Aerial statuses first (states are mutually exclusive)
                if(M.is_aerial_target)
                    for(var/datum/component/status/C in M.components)
                        if(C != src && C.is_aerial)
                            if(hascall(M, "RemoveStatus"))
                                call(M, "RemoveStatus")(C)
                            break
                M.is_burrowed = 1

        // 6. Grant active skills and passives while this status is active
        if(src.granted_skill_ids || src.granted_passive_ids)
            src.status_granted_skills = list()
            var/list/active_ids = src.granted_skill_ids ? src.granted_skill_ids : list()
            var/list/passive_ids = src.granted_passive_ids ? src.granted_passive_ids : list()

            for(var/sid in active_ids)
                var/datum/skill/GS = skill_factory.loaded_skills[sid]
                if(!GS) continue
                if(!(GS in M.skills))
                    M.skills += GS
                    M.equipped_skills += GS
                    src.status_granted_skills += GS

            for(var/sid in passive_ids)
                var/datum/skill/GS = skill_factory.loaded_skills[sid]
                if(!GS) continue
                if(!(GS in M.equipped_skills))
                    M.skills += GS
                    M.equipped_skills += GS
                    src.status_granted_skills += GS

        // 7. Remove Equipment
        if(src.remove_weapon && ("equipped_weapon" in M.vars) && M.equipped_weapon)
            src.stripped_item = M.equipped_weapon
            src.stripped_slot = "weapon"
            M.equipped_weapon = null
            if(hascall(M, "UpdateStats")) M.UpdateStats()
            world << "<font color='#CC4400'><b>[M.name]'s weapon was torn away!</b></font>"
        else if(src.remove_armor && ("equipped_armor" in M.vars) && M.equipped_armor)
            src.stripped_item = M.equipped_armor
            src.stripped_slot = "armor"
            M.equipped_armor = null
            if(hascall(M, "UpdateStats")) M.UpdateStats()
            world << "<font color='#CC4400'><b>[M.name]'s armor was stripped!</b></font>"
        else if(src.remove_accessory && ("equipped_accessory" in M.vars) && M.equipped_accessory)
            src.stripped_item = M.equipped_accessory
            src.stripped_slot = "accessory"
            M.equipped_accessory = null
            if(hascall(M, "UpdateStats")) M.UpdateStats()
            world << "<font color='#CC4400'><b>[M.name]'s accessory was removed!</b></font>"

        // 8. Mind Control: swap the mob's encounter party membership
        if(src.mind_control && M.current_encounter)
            var/datum/encounter/E = M.current_encounter
            if(M in E.players)
                src.was_in_players = 1
                E.players -= M
                E.enemies += M
                world << "<font color='#CC00CC'><b>[M.name] has been Mind Controlled!</b></font>"
            else if(M in E.enemies)
                src.was_in_players = 0
                E.enemies -= M
                E.players += M
                world << "<font color='#CC00CC'><b>[M.name] has been Mind Controlled and fights for you!</b></font>"

    proc/OnRemove(mob/M)
        // 1. Primary stat reversal
        if(src.stat_mod && src.stat_amount != 0)
            src.ModifyStat(M, src.stat_mod, -src.stat_amount)

        // 2. Second stat reversal
        if(src.second_stat && src.second_stat_amount != 0)
            src.ModifyStat(M, src.second_stat, -src.second_stat_amount)

        // 3. Vanish flag clear
        if(src.vanish && ("is_vanished" in M.vars))
            M.is_vanished = 0

        // 4. Aerial flag clear (only if no other aerial status remains)
        if(src.is_aerial && ("is_aerial_target" in M.vars))
            var/still_aerial = 0
            for(var/datum/component/status/C in M.components)
                if(C != src && C.is_aerial) still_aerial = 1
            if(!still_aerial) M.is_aerial_target = 0

        // 4b. Burrowed flag clear (only if no other burrowed status remains)
        if(src.is_burrowed && ("is_burrowed" in M.vars))
            var/still_burrowed = 0
            for(var/datum/component/status/C in M.components)
                if(C != src && C.is_burrowed) still_burrowed = 1
            if(!still_burrowed) M.is_burrowed = 0

        // 5. Death-on-expire (Death status)
        if(src.kills_on_expire && M && !M.is_dead)
            world << "<font color='#FF0000'><b>[M.name]'s time has run out!</b></font>"
            M.HandleDeath(null)

        // 6. Remove skills/passives that were granted by this status
        if(src.status_granted_skills)
            for(var/datum/skill/GS in src.status_granted_skills)
                M.skills -= GS
                M.equipped_skills -= GS
            src.status_granted_skills = null

        // 7. Restore stripped equipment
        if(src.stripped_item && src.stripped_slot != "")
            if(src.stripped_slot == "weapon" && ("equipped_weapon" in M.vars) && !M.equipped_weapon)
                M.equipped_weapon = src.stripped_item
                if(hascall(M, "UpdateStats")) M.UpdateStats()
                world << "<i>[M.name]'s [src.stripped_item.name] is returned.</i>"
            else if(src.stripped_slot == "armor" && ("equipped_armor" in M.vars) && !M.equipped_armor)
                M.equipped_armor = src.stripped_item
                if(hascall(M, "UpdateStats")) M.UpdateStats()
                world << "<i>[M.name]'s [src.stripped_item.name] is returned.</i>"
            else if(src.stripped_slot == "accessory" && ("equipped_accessory" in M.vars) && !M.equipped_accessory)
                M.equipped_accessory = src.stripped_item
                if(hascall(M, "UpdateStats")) M.UpdateStats()
                world << "<i>[M.name]'s [src.stripped_item.name] is returned.</i>"
            src.stripped_item = null
            src.stripped_slot = ""

        // 8. Mind Control reversal: restore original party membership
        if(src.mind_control && src.was_in_players >= 0 && M.current_encounter)
            var/datum/encounter/E = M.current_encounter
            if(src.was_in_players == 1)
                // Was originally a player — move back
                E.enemies -= M
                E.players += M
            else
                // Was originally an enemy — move back
                E.players -= M
                E.enemies += M
            src.was_in_players = -1
            world << "<font color='#CC00CC'><i>[M.name] breaks free from Mind Control!</i></font>"

    // Computes a flat change as a percentage of the mob's current base stat
    proc/ComputeStatPct(mob/M, stat, pct)
        var/bv = src.StatToBaseVar(stat)
        if(!bv || !(bv in M.vars)) return 0
        return round(M.vars[bv] * pct)

    proc/StatToBaseVar(stat)
        switch(uppertext(stat))
            if("STR") return "base_strength"
            if("DEX") return "base_dexterity"
            if("RES") return "base_resilience"
            if("INT") return "base_intelligence"
            if("MND") return "base_mind"
            if("VIT") return "base_vitality"
        return ""

    proc/ModifyStat(mob/M, stat, math_amt)
        var/bv = src.StatToBaseVar(stat)
        if(!bv || !(bv in M.vars)) return
        M.vars[bv] += math_amt
        if(hascall(M, "UpdateStats")) M.UpdateStats()

    // ============================================================
    // --- REFRESH ---
    // ============================================================
    OnRefresh(dur, amt)
        src.duration = max(src.duration, dur)
        src.max_duration = src.duration  // Reset max to match refreshed duration
        src.amount = max(src.amount, amt)
        // Wound stacking: each re-application doubles DoT damage
        if(src.stack_double && src.dot_amount > 0)
            src.dot_amount *= 2
            world << "<i><font color='#CC2200'>[src.name] worsens!</font></i>"

    // ============================================================
    // --- TURN START ---
    // ============================================================
    OnTurnStart(mob/M)
        if(!M || M.hp <= M.death_threshold) return

        // 1. Damage Over Time
        if(src.dot_amount > 0)
            var/dot_dmg = 0
            if(src.dot_is_percent)
                var/base_hp = src.dot_use_current ? M.hp : M.max_hp
                dot_dmg = round(base_hp * src.dot_amount)
            else
                dot_dmg = round(src.dot_amount)

            // Cannot Kill: floor remaining HP at 1
            if(src.dot_cannot_kill)
                dot_dmg = min(dot_dmg, M.hp - 1)

            if(dot_dmg > 0)
                if(src.dot_delayed_burst)
                    src.dot_accumulated += dot_dmg
                    world << "<i><small>[M.name] ([src.name]: [dot_dmg] stored, [M.hp] HP remaining)</small></i>"
                else
                    M.TakeDamage(dot_dmg, null, src.dot_type, 1)
                    world << "<i><font color='#CC4444'>[M.name] ([src.name]: [dot_dmg] damage, [M.hp] HP remaining)</font></i>"

        // 2. Parasite burst: fires accumulated damage on the NEXT turn (when duration ticks)
        if(src.dot_delayed_burst && src.dot_accumulated > 0 && src.duration == 1)
            var/burst = src.dot_accumulated
            src.dot_accumulated = 0
            if(src.dot_cannot_kill) burst = min(burst, M.hp - 1)
            if(burst > 0)
                world << "<font color='#CC0000'><b>[M.name] ([src.name] erupts: [burst] damage!)</b></font>"
                M.TakeDamage(burst, null, src.dot_type, 1)

        // 3. HP Heal Over Time
        if(src.hot_amount > 0)
            var/hot_heal = round(src.hot_amount)
            if(hascall(M, "ApplyHeal"))
                M.ApplyHeal(hot_heal, null)
            else
                M.hp += hot_heal
                M.ClampStats()
            world << "<i><font color='#00FF00'>[M.name] ([src.name]: [hot_heal] HP recovered, [M.hp] HP remaining)</font></i>"

        // 4. MP Restore per turn (Regen)
        if(src.hot_mp > 0)
            var/mp_regen = round(src.hot_mp)
            M.mp += mp_regen
            M.ClampStats()
            world << "<i><font color='#6699FF'>[M.name] ([src.name]: [mp_regen] MP recovered, [M.mp] MP remaining)</font></i>"

        // 5. MP Drain per turn (Sap)
        if(src.sap_mp > 0)
            var/mp_drain = min(round(src.sap_mp), M.mp)
            if(mp_drain > 0)
                M.mp -= mp_drain
                world << "<i><font color='#9933CC'>[M.name] ([src.name]: [mp_drain] MP drained, [M.mp] MP remaining)</font></i>"

    // ============================================================
    // --- TURN END ---
    // ============================================================
    OnTurnEnd(mob/M)
        // Guard: component may have already been removed by RemoveStatus() earlier this tick
        if(!owner || !(src in owner.components)) return
        if(src.duration > 0)
            src.duration--
            if(src.duration <= 0 && M)
                if(hascall(M, "RemoveStatus"))
                    call(M, "RemoveStatus")(src)

    // ============================================================
    // --- BEFORE DAMAGE (damage interception) ---
    // ============================================================
    OnBeforeDamage(damage, type, mob/attacker)
        if(!owner || !(src in owner.components)) return damage

        // 0a. Fortified: reduces all incoming damage by 20%
        if(src.id == "fortified" && damage > 0)
            damage = round(damage * 0.80)
            return damage

        // 0b. Barrier Shield: HP pool absorbs damage before anything else
        if(src.id == "barrier_shield" && src.amount > 0 && damage > 0)
            var/absorb = min(damage, src.amount)
            src.amount -= absorb
            damage -= absorb
            owner << "<font color='#4488FF'>Barrier absorbed [absorb] damage!</font>"
            if(src.amount <= 0)
                owner << "<b>The barrier shatters!</b>"
                if(hascall(owner, "RemoveStatus"))
                    spawn(0) call(owner, "RemoveStatus")(src)
            return damage

        // 1. Invincibility: block damage below threshold
        if(src.invincible_thresh > 0 && damage > 0 && damage < src.invincible_thresh)
            owner << "<font color='#FFD700'><b>INVINCIBLE! ([damage] blocked)</b></font>"
            return 0

        // 2. Elemental Resistance Shield / Vulnerability
        // findtext() handles dual-type strings like "Slashing Fire".
        // Negative damage_resist_pct (e.g. Curse Mark: -0.10) amplifies damage by that fraction.
        if(src.damage_resist_pct != 0)
            if(src.damage_resist_type == "" || findtext(type, src.damage_resist_type))
                var/resist = round(damage * src.damage_resist_pct)
                damage -= resist
                if(src.damage_resist_pct > 0)
                    owner << "<font color='#4488FF'>Resisted [resist] [type] damage!</font>"
                return max(0, damage)

        // 3. Mana Shield: route damage to MP first
        if(src.mana_shield && ("mp" in owner.vars))
            var/mp_absorb = min(damage, owner.mp)
            owner.mp -= mp_absorb
            damage -= mp_absorb
            if(mp_absorb > 0)
                owner << "<font color='#0044FF'>Mana Shield absorbed [mp_absorb] damage!</font>"
            return max(0, damage)

        // 4. Shatter: multiply damage, then break the disabling status
        if(src.full_disable && src.shatter_mult > 1.0)
            if(src.shatter_type == "" || findtext(type, src.shatter_type))
                damage = round(damage * src.shatter_mult)
                owner << "<font color='#FF2200'><b>CRITICAL SHATTER! [src.name] breaks!</b></font>"
                src.full_disable = 0
                src.shatter_mult = 1.0
                src.break_on_hit = 0
                if(hascall(owner, "RemoveStatus"))
                    spawn(0) call(owner, "RemoveStatus")(src)
                return damage

        // 5. Break-on-Hit: wake up from Sleep when damaged
        if(src.break_on_hit && damage > 0 && src.full_disable)
            owner << "<b>[owner.name] woke up!</b>"
            src.full_disable = 0
            src.break_on_hit = 0
            if(hascall(owner, "RemoveStatus"))
                spawn(0) call(owner, "RemoveStatus")(src)

        // 6. Dodge Chance (Charm / Time Stop)
        if(src.dodge_chance > 0 && prob(src.dodge_chance))
            owner << "<font color='#FF69B4'><b>[src.name] causes the attack to miss!</b></font>"
            // Time Stop: consume the status after first dodge
            if(src.dodge_once && hascall(owner, "RemoveStatus"))
                spawn(0) call(owner, "RemoveStatus")(src)
            return 0

        return damage

    // ============================================================
    // --- SIGNAL HOOK ---
    // ============================================================
    OnSignal(signal_id, passed_val)
        // Re-Raise: fires on SIG_DYING before is_dead is set
        // HandleDeath checks HP after SIG_DYING and skips death if HP > threshold
        if(signal_id == "SIG_DYING" && src.reraise && owner && !owner.is_dead)
            world << "<font color='#FFD700'><b>[owner.name]'s Re-Raise activates!</b></font>"
            owner.hp = max(1, round(owner.max_hp * 0.10))
            owner.is_downed = 0
            if(hascall(owner, "RemoveStatus"))
                call(owner, "RemoveStatus")(src)

// ============================================================
// AFFINITY COMPONENT
// Represents a typed damage affinity (Resist / Null / Absorb)
// on a mob. Created by UpdateStats() for armour pieces,
// and can also be added by passives or status effects.
//
// "source" is used to identify which affinities to remove
// during UpdateStats() so gear changes apply cleanly.
// ============================================================
datum/component/affinity
    var/physical_type  = ""     // "Slashing", "Piercing", "Blunt", "" = any physical
    var/elemental_type = ""     // "Fire", "Ice", etc. "" = any elemental
    var/affinity_type  = "Resist" // "Resist" | "Null" | "Absorb"
    var/resist_pct     = 0.0    // Used by Resist: positive = reduction, negative = vulnerability
    var/source         = ""     // "armor" | "passive" | "status"

    // Called by DamageContext.ResolveDamage() for each affinity on the defender.
    // Modifies DC.final_damage and sets DC.was_nulled, DC.was_absorbed, DC.hit_resist.
    proc/Apply(datum/damage_context/DC)
        // --- Match check ---
        // If neither type field is set, this affinity applies to all non-true damage.
        // Otherwise at least one typed field must match the incoming damage type.
        var/applies = 0
        if(src.physical_type == "" && src.elemental_type == "")
            applies = 1
        else
            if(src.physical_type != "" && DC.physical_type != "")
                if(findtext(DC.physical_type, src.physical_type)) applies = 1
            if(src.elemental_type != "" && DC.elemental_type != "")
                if(findtext(DC.elemental_type, src.elemental_type)) applies = 1
        if(!applies) return

        // --- Apply the affinity ---
        switch(src.affinity_type)
            if("Null")
                DC.final_damage = 0
                DC.was_nulled = 1
            if("Absorb")
                DC.was_absorbed = 1
            if("Resist")
                // Diminishing returns: multiply remaining damage by (1 - pct).
                // Negative pct (vulnerability) multiplies damage above 1.0 automatically.
                DC.final_damage = round(DC.final_damage * (1.0 - src.resist_pct))
                if(src.resist_pct > 0)
                    DC.hit_resist = 1

// ============================================================
// COUNTER WINDOW DATUM
// Created by skills with is_counter_stance=1. Tracks a timed
// window during which an incoming hit triggers the afterlink skill.
// Stored in mob/active_counter_windows (Base.dm).
// ============================================================
datum/counter_window
    var/mob/owner
    var/datum/skill/counter_skill   // The afterlink skill to fire on counter
    var/ticks_remaining = 50

    proc/Tick()
        src.ticks_remaining--
        if(src.ticks_remaining <= 0)
            src.Expire()

    proc/OnHit(mob/attacker)
        if(src.counter_skill && attacker)
            owner << "<b>Counter!</b>"
            src.counter_skill.ProcessTimeline(owner, attacker, owner.current_encounter, 1)
        src.Expire()

    proc/Expire()
        if(owner && owner.active_counter_windows)
            owner.active_counter_windows -= src
        del(src)