datum/class
    var/name = "Class"
    var/description = ""
    var/list/stat_growths = list()
    var/list/starting_stats = list()
    var/list/skill_tree = list()

datum/class/fighter
    name = "Fighter"
    description = "Master of close-quarters combat. Fast, aggressive, and technical. Uses fists and light weapons to overwhelm enemies with flurries of strikes, counters, and aerial combos."
    starting_stats = list(
        "base_strength"     = 3,
        "base_dexterity"    = 2,
        "base_intelligence" = 0,
        "base_mind"         = 0,
        "base_vitality"     = 2,
        "base_resilience"   = 1
    )
    stat_growths = list(
        "base_strength"     = 2,
        "base_dexterity"    = 1,
        "base_vitality"     = 1
    )
    skill_tree = list()

datum/class/warrior
    name = "Warrior"
    description = "Master of arms and iron will. Adaptable in both technique and armament. Wield swords with shields to protect allies, or grip greataxes to shatter defenses with overwhelming force."
    starting_stats = list(
        "base_strength"     = 2,
        "base_dexterity"    = 0,
        "base_intelligence" = 0,
        "base_mind"         = 1,
        "base_vitality"     = 2,
        "base_resilience"   = 3
    )
    stat_growths = list(
        "base_strength"     = 1,
        "base_mind"         = 1,
        "base_vitality"     = 1,
        "base_resilience"   = 1
    )
    skill_tree = list()

datum/class/rogue
    name = "Rogue"
    description = "Shadow stalker and silent killer. Punish enemies with dagger strikes and deadly venom. Layer poison and wounds on targets, then exploit the accumulated suffering with devastating finishers."
    starting_stats = list(
        "base_strength"     = 1,
        "base_dexterity"    = 4,
        "base_intelligence" = 0,
        "base_mind"         = 0,
        "base_vitality"     = 2,
        "base_resilience"   = 1
    )
    stat_growths = list(
        "base_strength"     = 1,
        "base_dexterity"    = 2,
        "base_vitality"     = 1
    )
    skill_tree = list()

datum/class/mage
    name = "Mage"
    description = "Channeler of destructive aether. Unleash elemental ruin from afar — fire burns, ice freezes, lightning stuns. Hit weaknesses, manage your MP, and weigh the risk of powerful spells."
    starting_stats = list(
        "base_strength"     = 0,
        "base_dexterity"    = 1,
        "base_intelligence" = 4,
        "base_mind"         = 2,
        "base_vitality"     = 0,
        "base_resilience"   = 1
    )
    stat_growths = list(
        "base_dexterity"    = 1,
        "base_intelligence" = 2,
        "base_mind"         = 1
    )
    skill_tree = list()

datum/class/cleric
    name = "Cleric"
    description = "Shield of light and mender of wounds. Heal allies, shield them with barriers, cleanse ailments, and prevent damage before it happens. A party without a Cleric is a party that dies."
    starting_stats = list(
        "base_strength"     = 0,
        "base_dexterity"    = 0,
        "base_intelligence" = 0,
        "base_mind"         = 4,
        "base_vitality"     = 2,
        "base_resilience"   = 2
    )
    stat_growths = list(
        "base_mind"         = 2,
        "base_vitality"     = 1,
        "base_resilience"   = 1
    )
    skill_tree = list()

datum/class/oracle
    name = "Oracle"
    description = "Unraveler of fate and breaker of wills. Dismantle enemies from the inside out with curses, hexes, and enfeebling magic. Stack debuffs, then detonate them all at once."
    starting_stats = list(
        "base_strength"     = 0,
        "base_dexterity"    = 1,
        "base_intelligence" = 3,
        "base_mind"         = 2,
        "base_vitality"     = 0,
        "base_resilience"   = 2
    )
    stat_growths = list(
        "base_intelligence" = 2,
        "base_mind"         = 1,
        "base_resilience"   = 1
    )
    skill_tree = list()
