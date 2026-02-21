/**
 * Message Event: Handles MsgList
 * Supports: (I) for user, (enemy) for target, and (c) for commas.
 */
datum/skill_event/message
    var/txt = ""
    is_global = 1 // <--- Automatically sets messages to only print once per skill

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!src.txt) return
        var/formatted_text = src.txt

        if(user)   formatted_text = replacetext(formatted_text, "(I)", user.name)
        if(target) formatted_text = replacetext(formatted_text, "(enemy)", target.name)
        formatted_text = replacetext(formatted_text, "(c)", ",")

        world << "<b>[formatted_text]</b>"
datum/skill_event/damage
    var/txt = "(I) hits (enemy)" // Updated the default text!
    var/formula = "ATK"
    var/accuracy = 100
    var/bypass_value = 0
    var/damage_type = "Physical"

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        // Guard Rail Check
        if(!user.CanAct(S) || !user.CanTarget(target)) return
        
        // Accuracy Check
        if(!prob(src.accuracy))
            world << "<i>[user.name] attacks [target.name] but misses!</i>"
            return

        var/raw_dmg = parser.Evaluate(src.formula, user, target)
        var/final_dmg = target.CalculateDamage(raw_dmg, S.damage_type, user)
        
        // --- NEW STRING PARSING ---
        var/formatted_text = src.txt
        if(user)   formatted_text = replacetext(formatted_text, "(I)", user.name)
        if(target) formatted_text = replacetext(formatted_text, "(enemy)", target.name)
        
        // Output using the formatted text
        var/hp_log = (target.hp - final_dmg <= 0) ? " ([target.hp - final_dmg] HP)" : ""
        world << "<b>[formatted_text] ([final_dmg] Damage)[hp_log]</b>"
        
        target.TakeDamage(raw_dmg, user, S.damage_type, silent = 1)

datum/skill_event/heal
    var/formula = "AP"

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!user.CanAct(S)) return
        
        var/amt = parser.Evaluate(src.formula, user, target)
        target.hp += amt
        target.ClampStats()
        
        world << "<b>[target.name] is restored for [amt] HP! ([target.hp] HP)</b>"

/**
 * Sound Event: Handles SndList
 */
datum/skill_event/sound
    var/sound_file

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!src.sound_file) return

        for(var/mob/M in E.all_participants)
            M << sound(src.sound_file)

/**
 * Status/Inflict Event: Handles Inflict, Chance, and Amount
 */
datum/skill_event/inflict
    var/status_type
    var/chance = 100
    var/amount = 0
    var/duration = 3

    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        if(!prob(src.chance)) return
        if(target) // The compiler now knows 'target' is a mob because of the line above
            target.ApplyStatus(src.status_type, src.duration, src.amount)