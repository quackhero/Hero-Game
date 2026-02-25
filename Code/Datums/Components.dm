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
        if(src.duration > 0)
            src.duration--
            if(src.duration <= 0)
                // Auto-delete when time is up
                if(M && hascall(M, "RemoveStatus"))
                    call(M, "RemoveStatus")(src) // <--- FIXED HERE
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
    
    // --- OVERRIDES (Notice we removed "var/" here) ---
    name = "Unknown Status"
    amount = 0
    duration = 0
    owner = null

    // --- CE2 Trigger Integration (These are new, so we keep "var/") ---
    var/trigger_condition = ""
    var/trigger_chance = 100
    var/reaction_skill_id = "" 
    var/trigger_category = "Any"

    var/dot_amount = 0
    var/dot_type = "Poison"
    var/hot_amount = 0

    // var/is_fresh = 1

    // --- THE CLONER ---
    // The factory uses this to hand a fresh copy to the player!
    proc/Clone()
        var/datum/component/status/S = new()
        S.id = src.id
        S.name = src.name
        S.trigger_condition = src.trigger_condition
        S.trigger_chance = src.trigger_chance
        S.reaction_skill_id = src.reaction_skill_id
        S.trigger_category = src.trigger_category
        S.dot_amount = src.dot_amount
        S.dot_type = src.dot_type  
        S.hot_amount = src.hot_amount
        return S

    // --- OVERRIDES (Notice we removed "proc/" here) ---
    OnRefresh(dur, amt)
        src.duration = max(src.duration, dur)
        src.amount = max(src.amount, amt)

    OnTurnStart(mob/M)
        if(!M || M.hp <= 0) return 

        // 1. Damage Over Time
        if(src.dot_amount > 0)
            world << "<i><font color='#800080'>[M.name] suffers [src.dot_amount] [src.dot_type] damage from [src.name]!</font></i>"
            // We pass 'null' for the attacker since the status itself is hurting them
            M.TakeDamage(src.dot_amount, null, src.dot_type, 1) 

        // 2. Heal Over Time
        if(src.hot_amount > 0)
            M.hp += src.hot_amount
            M.ClampStats() // Ensure they don't heal over max_hp
            world << "<i><font color='#00FF00'>[M.name] recovers [src.hot_amount] HP from [src.name]!</font></i>"

    OnTurnEnd(mob/M)
        world << "DEBUG: [src.name] fresh=[src.is_fresh] duration=[src.duration]"

        if(src.duration > 0)
            src.duration--
            if(src.duration <= 0 && M)
                if(hascall(M, "RemoveStatus"))
                    call(M, "RemoveStatus")(src) // <--- FIXED HERE