mob
    proc/SavePlayer()
        if(!src.ckey) return 
        var/savefile/F = new("Saves/[src.ckey].sav")
        
        F["name"] << src.name
        F["level"] << src.level
        F["stat_points"] << src.stat_points
        
        // Save current health and mana
        F["hp"] << src.hp
        F["mp"] << src.mp
        
        // Save BASE stats (so equipment bonuses don't accidentally get permanently baked in)
        F["base_max_hp"] << src.base_max_hp
        F["base_max_mp"] << src.base_max_mp
        F["base_strength"] << src.base_strength
        F["base_dexterity"] << src.base_dexterity
        F["base_intelligence"] << src.base_intelligence
        F["base_mind"] << src.base_mind
        F["base_vitality"] << src.base_vitality
        F["base_resilience"] << src.base_resilience

        if(src.Primary_class)
            F["class"] << src.Primary_class.type

        // --- NEW: Dynamic Skill Saving ---
        var/list/skill_paths_to_save = list()
        for(var/datum/skill/S in src.skills)
            skill_paths_to_save += S.type // Add the blueprint path to the list
            
        F["skills"] << skill_paths_to_save // Save the list of paths

    proc/LoadPlayer()
        if(!src.ckey) return 0
        if(!fexists("Saves/[src.ckey].sav")) return 0 
        
        var/savefile/F = new("Saves/[src.ckey].sav")
        
        F["name"] >> src.name
        F["level"] >> src.level
        F["stat_points"] >> src.stat_points
        
        F["hp"] >> src.hp
        F["mp"] >> src.mp
        
        // Load BASE stats
        F["base_max_hp"] >> src.base_max_hp
        F["base_max_mp"] >> src.base_max_mp
        F["base_strength"] >> src.base_strength
        F["base_dexterity"] >> src.base_dexterity
        F["base_intelligence"] >> src.base_intelligence
        F["base_mind"] >> src.base_mind
        F["base_vitality"] >> src.base_vitality
        F["base_resilience"] >> src.base_resilience

        var/class_path
        F["class"] >> class_path
        if(class_path)
            src.Primary_class = new class_path()
        
        // --- NEW: Dynamic Skill Loading ---
        var/list/saved_skill_paths = list()
        F["skills"] >> saved_skill_paths // Load the list of paths
        
        if(saved_skill_paths)
            for(var/path in saved_skill_paths)
                src.skills += new path() // Rebuild each skill from its path
        
        // --- REBUILD STATS ---
        // Recalculate their true stats (Base + Equipment) now that base stats are loaded
        src.UpdateStats()
        
        return 1