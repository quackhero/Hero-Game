// ============================================================
// 1. THE COUNTER EVENT 
// ============================================================
// This is NOT a component. It lives in the 'active_counters' list.
datum/skill_event/counter
    var/duration = 50       // Time in ticks
    var/trigger_id = ""     // Signal to listen for (ON_HIT)
    var/datum/skill/after_skill // The skill to fire back with

    proc/OnSignal(mob/owner, signal_id, passed_val)
        if(signal_id == src.trigger_id)
            if(after_skill)
                owner << "<b>Counter Triggered!</b>"
                var/mob/target = passed_val
                
                // Fire the counter skill at the attacker
                if(ismob(target))
                    after_skill.Execute(owner, target, owner.current_encounter)
            
            // Remove the counter so it fires only once
            owner.active_counters -= src
            del(src)

// ============================================================
// 2. COMBAT COMPONENTS
// ============================================================

// --- SHIELD COMPONENT ---
// Absorbs damage until it breaks
datum/component/shield
    var/hp = 0
    
    New(amount, time)
        src.hp = amount
        src.duration = time
        src.name = "Shield"

    // Intercept damage before it hits the HP
    OnBeforeDamage(damage, type, mob/attacker)
        if(src.hp <= 0) return damage

        var/absorb = min(damage, src.hp)
        src.hp -= absorb
        damage -= absorb
        
        owner << "<font color='blue'>Shield absorbed [absorb] damage!</font>"
        
        if(src.hp <= 0)
            owner << "<b>Your shield broke!</b>"
            owner.components -= src
            del(src)
            
        return damage


// ============================================================
// 3. DAMAGE OVER TIME (DoT) FAMILY
// ============================================================
// Covers: Poison, Burn (all types), Demi, Parasite, Toxin, Wounds
datum/component/dot
    var/damage_type = "True" // "Fire", "Bio", "Dark"
    var/is_percentage = 0    // If 1, amount is % (0.1 = 10%)
    var/use_current_hp = 0   // If 1, uses Current HP (Demi)
    var/delayed_burst = 0    // If 1, damage waits until end (Parasite)
    var/accumulated_dmg = 0  // Stores damage for Parasite
    
    // Scaling variables for Wounds
    var/increment_val = 0
    var/max_amount = 0

    New(amt, dur, type="True", perc=0, cur=0, delay=0)
        src.amount = amt
        src.duration = dur
        src.damage_type = type
        src.is_percentage = perc
        src.use_current_hp = cur
        src.delayed_burst = delay
        src.name = "DoT"

    OnTurnStart(mob/owner)
        // 1. Calculate Damage
        var/dmg = src.amount
        
        if(src.is_percentage)
            if(src.use_current_hp)
                dmg = round(owner.hp * src.amount) // Demi logic
            else
                dmg = round(owner.max_hp * src.amount) // Burn logic

        // 2. Apply or Store
        if(src.delayed_burst)
            src.accumulated_dmg += dmg
            owner << "<small>The parasite grows...</small>"
        else
            // 'silent = 1' prevents the standard attack message
            owner.TakeDamage(dmg, null, src.damage_type, silent = 1)
            world << "<font color='#FF4444'><b>[owner.name] takes [dmg] [src.name] damage!</b></font>"

        // 3. Scaling Logic (For Wounds)
        if(src.increment_val > 0)
            src.amount += src.increment_val
            if(src.max_amount > 0)
                src.amount = min(src.amount, src.max_amount)

// ============================================================
// 4. STAT MODIFIER FAMILY (Buffs & Debuffs)
// ============================================================
// Covers: Haste, Slow, En-Strength, De-Armor, Attack Break
datum/component/stat_mod
    var/stat_name = ""       // "ATK", "DEF", "SPD", "AP"
    var/mod_amount = 0       // Amount to add/sub (e.g., -10, +50)
    var/is_multiplier = 0    // If 1, we multiply instead (0.5 = Halve)
    
    New(stat, amt, dur, mult=0)
        src.stat_name = stat
        src.mod_amount = amt
        src.duration = dur
        src.is_multiplier = mult
        src.name = "Stat Mod"
        
        // Apply immediately upon creation
        if(owner) ApplyMod(owner)

    // Helper to apply the math
    proc/ApplyMod(mob/M)
        if(stat_name in M.vars)
            if(is_multiplier)
                M.vars[stat_name] *= mod_amount
            else
                M.vars[stat_name] += mod_amount
            M << "<b>[stat_name] changed by [mod_amount]!</b>"

    // Helper to revert the math (Cleanup)
    proc/RemoveMod(mob/M)
        if(stat_name in M.vars)
            if(is_multiplier)
                if(mod_amount != 0) M.vars[stat_name] /= mod_amount
            else
                M.vars[stat_name] -= mod_amount

    Del()
        if(owner) RemoveMod(owner)
        ..()

// ============================================================
// 5. CROWD CONTROL (Disable) FAMILY
// ============================================================
// Covers: Stun, Sleep, Freeze, Petrify, Stop, Silence, Blind
datum/component/disable
    var/disable_flags = 0    // What action is blocked? (Bitflags)
    var/break_on_hit = 0     // Does getting hit cure this? (Sleep)
    var/shatter_mult = 1.0   // Damage multiplier if hit (Freeze/Petrify)
    var/shatter_type = ""    // Specific element needed to shatter (e.g. "Fire")

    New(flags, dur, break_hit=0, shat_mult=1.0, shat_type="")
        src.disable_flags = flags
        src.duration = dur
        src.break_on_hit = break_hit
        src.shatter_mult = shat_mult
        src.shatter_type = shat_type
        src.name = "Disable"

        if(owner) 
            owner.combat_flags |= src.disable_flags
            owner.is_busy = 1 

    Del()
        if(owner)
            owner.combat_flags &= ~src.disable_flags 
            
            var/still_busy = 0
            for(var/datum/component/disable/D in owner.components)
                if(D != src) still_busy = 1
            
            if(!still_busy) owner.is_busy = 0
            
            owner << "<b>You are no longer [src.name]!</b>"
        ..()

    OnBeforeDamage(damage, type, mob/attacker)
        if(src.shatter_mult > 1.0)
            if(src.shatter_type == "" || src.shatter_type == type)
                damage *= src.shatter_mult
                owner << "<font color='red'><b>CRITICAL SHATTER!</b></font>"
                src.duration = 0 
                Del()
                return damage

        if(src.break_on_hit && damage > 0)
            owner << "<b>You woke up!</b>"
            src.duration = 0
            Del()
            
        return damage