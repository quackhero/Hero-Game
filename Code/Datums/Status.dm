datum/status
    var/name = "Status"
    var/duration = 0
    var/amount = 0
    var/mob/owner = null

    // --- CE2 TRIGGER INTEGRATION ---
    var/trigger_condition = ""
    var/trigger_chance = 100
    var/reaction_skill_id = "" // The JSON skill ID it fires when triggered!

    proc/OnApply()
        return
        
    proc/OnRemove()
        return
        
    // Called automatically at the start of their turn!
    proc/OnTurnStart()
        return

// ==========================================
// EXAMPLE STATUSES
// ==========================================

// 1. The Active Counter Stance
datum/status/vengeful_stance
    name = "Vengeful Stance"
    trigger_condition = "OnDamaged"
    trigger_chance = 100
    reaction_skill_id = "vengeful_strike" // Points directly to your JSON skill!

// 2. A Classic Damage-Over-Time
datum/status/poison
    name = "Poison"
    OnTurnStart()
        if(owner && amount > 0)
            owner.hp -= amount
            world << "<i><font color='#32CD32'>[owner.name] suffers [amount] Poison damage!</font></i>"
            owner.ClampStats()