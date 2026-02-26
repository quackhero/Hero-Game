datum/class
    var/name = "Class"
    var/list/stat_growths = list()
    var/list/skill_tree = list()

datum/class/novice
    name = "Novice"
    stat_growths = list(
        "base_max_hp"     = 3,
        "base_max_mp"     = 1,
        "base_strength"   = 2,
        "base_resilience" = 1,
        "base_dexterity"  = 1,
        "base_intelligence" = 1,
        "base_mind"       = 1,
        "base_vitality"   = 2
    )

    skill_tree = list(
        "2" = /datum/skill/heavy_strike
    )
