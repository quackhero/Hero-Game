/**
 * CLASS DATUMS
 * Defines the auto-stat growths and skill trees for classes/jobs.
 */
datum/class
    var/name = "Class"
    var/list/stat_growths = list()
    var/list/skill_tree = list()

datum/class/novice
    name = "Novice"
    // Changed to target the new "base_" stats
    stat_growths = list(
        "base_max_hp" = 3, 
        "base_max_mp" = 1, 
        "base_atk" = 2, 
        "base_def" = 1, 
        "base_spd" = 1
    )
    
    skill_tree = list(
        "2" = /datum/skill/heavy_strike,
        "4" = /datum/skill/cure
    )