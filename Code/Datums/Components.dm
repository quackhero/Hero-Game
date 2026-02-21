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
    proc/OnTurnStart()
        return

    // Runs at the end of the mob's turn (Tick down duration)
    proc/OnTurnEnd()
        if(src.duration > 0)
            src.duration--
            if(src.duration <= 0)
                // Auto-delete when time is up
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