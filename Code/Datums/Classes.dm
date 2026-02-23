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
    stat_growths = list(
        "max_hp" = 3, 
        "max_mp" = 1, 
        "strength" = 2, 
        "resilience" = 1, 
        "dexterity" = 1,
        "intelligence" = 1,
        "mind" = 1,
        "vitality" = 2
    )
    
    
    skill_tree = list(
        "2" = /datum/skill/heavy_strike,
        "4" = /datum/skill/cure
    )