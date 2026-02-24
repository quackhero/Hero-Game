datum/skill/fire
    name = "Fire"
    cost = 9
    damage_type = "Fire"
    New()
        var/datum/skill_event/damage/D = new(); D.txt = "blasts"; D.formula = "AP * 1.75"
        src.event_timeline += D

datum/skill/explosion
    name = "Explosion"
    cost = 20
    targeting_flags = TARGET_AOE

    New()
        var/datum/skill_event/message/M = new()
        // Add (I) here so it prints the user's name!
        M.txt = "(I) unleashes a massive explosion!"

        var/datum/skill_event/damage/D = new()
        D.formula = "AP * 2"
        // Add (enemy) here so it puts the target's name at the front!
        D.txt = "(enemy) is scorched by the blast!"

        src.event_timeline += M
        src.event_timeline += D


datum/skill/vengeful_strike
    name = "Vengeful Strike"
    cost = 5

    New()
        var/datum/skill_event/damage/D = new()
        D.txt = "unleashes a desperate strike at"
        // Deals more damage the further below 0 HP you are!
        D.formula = "ATK + (abs(min(0, HP)) * 2)"
        src.event_timeline += D



// 1. Define what 'Burn' is
datum/component/dot/burn
    name = "Burn"
    damage_type = "Fire"

// 2. Create the Ignite skill
datum/skill/ignite
    name = "Ignite"
    cost = 8

    New()
        var/datum/skill_event/message/M = new()
        M.txt = "(I) snaps their fingers!"

        var/datum/skill_event/damage/D = new()
        D.formula = "AP * 1"
        D.txt = "(enemy) bursts into flames"

        // 3. The Inflict Event
        var/datum/skill_event/inflict/I = new()
        I.status_type = /datum/component/dot/burn
        I.amount = 5      // 5 Damage per turn
        I.duration = 3    // Lasts 3 turns
        I.chance = 100    // 100% chance to apply

        src.event_timeline += M
        src.event_timeline += D
        src.event_timeline += I
datum/skill/heavy_strike
    name = "Heavy Strike"
    cost = 10

    New()
        var/datum/skill_event/damage/D = new()
        // We added (I) and (enemy) so the engine knows where to put the names!
        D.txt = "(I) delivers a crushing blow to (enemy)!"
        D.formula = "ATK * 1.5"

        src.event_timeline += D