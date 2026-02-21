mob
    proc/SavePlayer()
        if(!src.ckey) return 
        var/savefile/F = new("Saves/[src.ckey].sav")
        
        F["name"] << src.name
        F["level"] << src.level
        F["stat_points"] << src.stat_points
        
        F["hp"] << src.hp
        F["max_hp"] << src.max_hp
        F["mp"] << src.mp
        F["max_mp"] << src.max_mp
        
        F["atk"] << src.atk
        F["def"] << src.def
        F["spd"] << src.spd
        F["ap"] << src.ap

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
        F["max_hp"] >> src.max_hp
        F["mp"] >> src.mp
        F["max_mp"] >> src.max_mp
        
        F["atk"] >> src.atk
        F["def"] >> src.def
        F["spd"] >> src.spd
        F["ap"] >> src.ap

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
        
        return 1