mob
    // Returns the save key for a skill:
    //   JSON skills  → their string id   (e.g. "basic_attack")
    //   DM skills    → their type path   (e.g. "/datum/skill/heavy_strike")
    // The leading "/" is what distinguishes them on load.
    proc/SkillSaveKey(datum/skill/S)
        if(S.id != "") return S.id
        return "[S.type]"

    proc/SavePlayer()
        if(!src.ckey) return
        var/savefile/F = new("Saves/[src.ckey].sav")

        F["name"]        << src.name
        F["level"]       << src.level
        F["current_exp"] << src.current_exp
        F["stat_points"] << src.stat_points

        F["hp"] << src.hp
        F["mp"] << src.mp

        // Save BASE stats (equipment bonuses must not be baked in permanently)
        F["base_max_hp"]       << src.base_max_hp
        F["base_max_mp"]       << src.base_max_mp
        F["base_strength"]     << src.base_strength
        F["base_dexterity"]    << src.base_dexterity
        F["base_intelligence"] << src.base_intelligence
        F["base_mind"]         << src.base_mind
        F["base_vitality"]     << src.base_vitality
        F["base_resilience"]   << src.base_resilience

        if(src.Primary_class)
            F["class"] << src.Primary_class.type

        // --- Skill Saving ---
        // JSON skills are saved by string id ("basic_attack").
        // Hardcoded DM skills are saved by type path ("/datum/skill/heavy_strike").
        var/list/skill_keys = list()
        for(var/datum/skill/S in src.skills)
            skill_keys += src.SkillSaveKey(S)
        F["skills"] << skill_keys

        // Save the equipped loadout so slot order is preserved on load.
        var/list/equipped_keys = list()
        for(var/datum/skill/S in src.equipped_skills)
            equipped_keys += src.SkillSaveKey(S)
        F["equipped_skills"] << equipped_keys

    proc/LoadPlayer()
        if(!src.ckey) return 0
        if(!fexists("Saves/[src.ckey].sav")) return 0

        var/savefile/F = new("Saves/[src.ckey].sav")

        F["name"]        >> src.name
        F["level"]       >> src.level
        F["current_exp"] >> src.current_exp
        F["stat_points"] >> src.stat_points

        F["hp"] >> src.hp
        F["mp"] >> src.mp

        // Load BASE stats
        F["base_max_hp"]       >> src.base_max_hp
        F["base_max_mp"]       >> src.base_max_mp
        F["base_strength"]     >> src.base_strength
        F["base_dexterity"]    >> src.base_dexterity
        F["base_intelligence"] >> src.base_intelligence
        F["base_mind"]         >> src.base_mind
        F["base_vitality"]     >> src.base_vitality
        F["base_resilience"]   >> src.base_resilience

        var/class_path
        F["class"] >> class_path
        if(class_path)
            src.Primary_class = new class_path()

        // --- Skill Loading ---
        var/list/skill_keys = list()
        F["skills"] >> skill_keys
        if(skill_keys)
            for(var/key in skill_keys)
                if(copytext(key, 1, 2) == "/")
                    // Hardcoded DM skill — instantiate from its type path.
                    var/skill_path = text2path(key)
                    if(skill_path) src.skills += new skill_path()
                else
                    // JSON skill — retrieve the live instance from the factory.
                    var/datum/skill/S = skill_factory.loaded_skills[key]
                    if(S) src.skills += S

        // --- Equipped Skill Loadout ---
        var/list/equipped_keys = list()
        F["equipped_skills"] >> equipped_keys
        if(equipped_keys)
            for(var/eq_key in equipped_keys)
                // Match each saved key against the just-loaded skill list.
                for(var/datum/skill/S in src.skills)
                    if(src.SkillSaveKey(S) == eq_key)
                        src.equipped_skills += S
                        break

        // Recalculate true stats (base + passives + equipment) now that everything is loaded.
        src.UpdateStats()
        return 1
