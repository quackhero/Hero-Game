mob/proc/CalculateDamage(raw_amount, damage_type = "Physical", mob/attacker, bypass = 0)
    // 1. Initial Math
    var/final_damage = raw_amount
    var/effective_def = max(0, src.resilience - bypass) // Bypass reduces effective DEF, but not below 0
    
    // 2. Defense Reduction
    // We subtract the target's DEF from the incoming ATK
    final_damage -= effective_def
    
    // 3. Stance Modifiers
    if(src.defending)
        final_damage = round(final_damage / 2)
        world << "<i>[src.name] mitigated damage with a defensive stance!</i>"

    // 4. Hook: Elemental Processing
    // This is where your Fire/Ice/Necrotic logic will live
    final_damage = src.ApplyElementalModifiers(final_damage, damage_type)

    // 5. Hook: Passive/Status Processing
    // Check for "Shields," "Buffs," or "Debuffs"
    final_damage = src.ApplyStatusModifiers(final_damage)

    // 6. Safety Floor
    // Ensure an attack never heals or does 0 unless intended
    return max(1, final_damage)

mob/proc/ApplyElementalModifiers(amount, type)
    var/modified_amount = amount
    
    // Example placeholder logic for your future Necrotic/Fire systems:
    /*
    switch(type)
        if("Fire")
            if(src.weak_to_fire) modified_amount *= 2
        if("Necrotic")
            if(src.is_undead) modified_amount = 0 // Heals instead?
    */
    
    return modified_amount

mob/proc/ApplyStatusModifiers(amount)
    // Placeholder for future things like "Poison" or "Magic Shield"
    return amount