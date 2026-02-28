// ============================================================
// 1. mob/enemy — base enemy subtype declaration
// ============================================================

mob/enemy
    var/base_exp = 50                   // EXP rewarded on defeat
    var/gil_reward = 0                  // Gil rewarded on defeat
    var/ai_difficulty = 0               // 0=Weak, 2=Aggressive, 4=Brutal, 5=Merciless, 6=Leader, 7=Ultimate
    var/attribute = ""                  // Element/creature type tag (e.g. "Fire", "Earth", "Wind")
    var/npc_id = ""                     // JSON template ID this was spawned from

    // Basic attack flavor text. null = no extra message (skill handles its own output).
    // If equipped_weapon also has attack_messages, the weapon takes precedence.
    var/list/attack_messages

    var/hero_status = 0                 // 0=Normal, 1=Hero, 2=Sidekick (for ally summoning)
    var/list/loot_table = list()        // assoc: item_id|type_path → drop chance %

    // --- Battle Barks ---
    // Assoc list: "bark_type" = list("message1", "message2", ...)
    // Active types: "war_cry", "taunt", "death", "kill", "hurt", "win"
    // Stored types: "rebirth", "surprise", "ambush", "comeback", "ultimate", "overkill"
    var/list/barks

    // --- Future Systems (stored from JSON, not yet active) ---
    var/list/opportunities              // Contextual skills granted to players for facing this NPC
    var/list/finisher_opportunities     // Cinematic finisher skills with trigger conditions

    // Picks a random message of the given bark type and displays it.
    proc/Bark(bark_type)
        if(!src.barks) return
        var/list/messages = src.barks[bark_type]
        if(!messages || !messages.len) return
        var/msg = pick(messages)
        msg = replacetext(msg, "(I)",    src.name)
        msg = replacetext(msg, "(user)", src.name)
        world << "<i><font color='#CCAA44'>[msg]</font></i>"


// ============================================================
// 2. Hardcoded enemies (preserved for debug verbs)
// ============================================================

mob/enemy/training_dummy
    name = "Training Dummy"
    level = 1
    base_exp = 50

    max_hp = 10
    hp = 10
    strength = 0
    resilience = 5
    dexterity = 15

    New()
        ..()
        src.skills += new /datum/skill/heavy_strike()


mob/enemy/active_dummy
    name = "Striking Dummy"
    hp = 500
    max_hp = 500
    strength = 1
    resilience = 5
    dexterity = 0
