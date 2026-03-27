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
    skill_tree = list(
        "1"  = "fighter_dual_punch",
        "2"  = "fighter_counter_stance",
        "3"  = "fighter_fighting_spirit",
        "4"  = "fighter_jump_kick",
        "5"  = "fighter_uppercut",
        "7"  = "fighter_dodge",
        "8"  = "fighter_feint",
        "10" = "fighter_flurry",
        "12" = "fighter_bravery",
        "14" = "fighter_sweep_kick",
        "15" = "fighter_self_defense",
        "17" = "fighter_duelascend",
        "19" = "fighter_leg_sweep",
        "21" = "fighter_momentum",
        "23" = "fighter_elbow_smash",
        "25" = "fighter_rising_storm"
    )

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
    skill_tree = list(
        "1"  = "warrior_power_strike",
        "2"  = "warrior_taunt",
        "3"  = "warrior_bravery",
        "5"  = "warrior_war_cry",
        "6"  = "warrior_open_wound",
        "8"  = "warrior_shield_bash",
        "9"  = "warrior_guard_up",
        "10" = "warrior_protect",
        "12" = "warrior_heavy_cleave",
        "14" = "warrior_gash_wound",
        "15" = "warrior_conditioning",
        "17" = "warrior_shield_wall",
        "19" = "warrior_armor_break",
        "21" = "warrior_fortify",
        "23" = "warrior_rallying_cry",
        "25" = "warrior_swordstrike"
    )

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
    skill_tree = list(
        "1"  = "rogue_quick_stab",
        "2"  = "rogue_poison_strike",
        "3"  = "rogue_dodge",
        "5"  = "rogue_smoke_bomb",
        "6"  = "rogue_cheap_shot",
        "8"  = "rogue_lacerate",
        "10" = "rogue_backstab",
        "11" = "rogue_nimble",
        "13" = "rogue_toxic_blade",
        "15" = "rogue_vanish",
        "17" = "rogue_gash",
        "19" = "rogue_fan_of_knives",
        "21" = "rogue_exploit_weakness",
        "23" = "rogue_ambush",
        "25" = "rogue_shadow_dance"
    )

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
    skill_tree = list(
        "1"  = "mage_fire",
        "2"  = "mage_blizzard",
        "3"  = "mage_thunder",
        "4"  = "mage_arcane_focus",
        "6"  = "mage_siphon",
        "8"  = "mage_mana_shield",
        "10" = "mage_fire_rain",
        "11" = "mage_attunement",
        "13" = "mage_blizzard_storm",
        "15" = "mage_elemental_sight",
        "17" = "mage_fira",
        "19" = "mage_thunder_storm",
        "20" = "mage_concentrate",
        "23" = "mage_barrier_burst",
        "25" = "mage_explosion"
    )

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
    skill_tree = list(
        "1"  = "cleric_cure",
        "2"  = "cleric_detox",
        "4"  = "cleric_protect",
        "5"  = "cleric_replenish",
        "7"  = "cleric_mend",
        "9"  = "cleric_holy_light",
        "10" = "cleric_regen",
        "12" = "cleric_release",
        "14" = "cleric_cura",
        "15" = "cleric_raise",
        "17" = "cleric_light_valor",
        "19" = "cleric_cure_wave",
        "21" = "cleric_barrier",
        "23" = "cleric_haste",
        "25" = "cleric_curaga"
    )

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
    skill_tree = list(
        "1"  = "oracle_hex",
        "2"  = "oracle_read_fate",
        "4"  = "oracle_curse_mark",
        "5"  = "oracle_foresight",
        "7"  = "oracle_enfeeble",
        "8"  = "oracle_sap",
        "10" = "oracle_doom_gaze",
        "12" = "oracle_slow",
        "14" = "oracle_dispel",
        "15" = "oracle_evil_eye",
        "17" = "oracle_drain_touch",
        "19" = "oracle_weaken",
        "20" = "oracle_misfortune",
        "23" = "oracle_mind_break",
        "25" = "oracle_unravel"
    )
