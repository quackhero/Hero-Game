mob
    var/datum/class/Primary_class
    var/current_exp = 0
    var/max_exp = 100
    var/level = 1
    var/stat_points = 0
    var/gil = 0

    // --- NEW: INVENTORY & EQUIPMENT ---
    var/list/inventory = list()
    var/datum/item/equipment/equipped_weapon
    var/datum/item/equipment/equipped_armor
    var/datum/item/equipment/equipped_accessory

    // --- NEW: BASE STATS (Naked Stats) ---
    var/base_max_hp = 100
    var/base_max_mp = 50
    var/base_strength = 10
    var/base_dexterity = 10
    var/base_intelligence = 10
    var/base_mind = 10
    var/base_vitality = 10
    var/base_resilience = 10

    // --- THE MATH ENGINE ---
    proc/UpdateStats()
        // 0a. Remove any skills previously granted by gear so we start clean.
        //     This handles unequip: the old skill is removed before we re-add from
        //     whatever is currently equipped.
        if(src.gear_granted_skills)
            for(var/datum/skill/GS in src.gear_granted_skills)
                src.skills        -= GS
                src.equipped_skills -= GS
        src.gear_granted_skills = list()

        // 0b. Remove all armour-sourced affinity components so we can re-add them
        //     fresh from whatever gear is currently equipped.
        var/list/old_affinities = list()
        for(var/datum/component/affinity/A in src.components)
            if(A.source == "armor") old_affinities += A
        for(var/datum/component/affinity/A in old_affinities)
            src.components -= A
            del(A)

        // 1. Reset to naked stats
        src.max_hp = src.base_max_hp
        src.max_mp = src.base_max_mp
        src.strength = src.base_strength
        src.dexterity = src.base_dexterity
        src.intelligence = src.base_intelligence
        src.mind = src.base_mind
        src.vitality = src.base_vitality
        src.resilience = src.base_resilience

        // 2. Add Weapon Stats
        if(src.equipped_weapon)
            src.max_hp += src.equipped_weapon.max_hp_bonus
            src.max_mp += src.equipped_weapon.max_mp_bonus
            src.strength += src.equipped_weapon.strength_bonus
            src.dexterity += src.equipped_weapon.dexterity_bonus
            src.intelligence += src.equipped_weapon.intelligence_bonus
            src.mind += src.equipped_weapon.mind_bonus
            src.vitality += src.equipped_weapon.vitality_bonus
            src.resilience += src.equipped_weapon.resilience_bonus

        // 3. Add Armor Stats
        if(src.equipped_armor)
            src.max_hp += src.equipped_armor.max_hp_bonus
            src.max_mp += src.equipped_armor.max_mp_bonus
            src.strength += src.equipped_armor.strength_bonus
            src.dexterity += src.equipped_armor.dexterity_bonus
            src.intelligence += src.equipped_armor.intelligence_bonus
            src.mind += src.equipped_armor.mind_bonus
            src.vitality += src.equipped_armor.vitality_bonus
            src.resilience += src.equipped_armor.resilience_bonus

        // 4. Add Accessory Stats
        if(src.equipped_accessory)
            src.max_hp += src.equipped_accessory.max_hp_bonus
            src.max_mp += src.equipped_accessory.max_mp_bonus
            src.strength += src.equipped_accessory.strength_bonus
            src.dexterity += src.equipped_accessory.dexterity_bonus
            src.intelligence += src.equipped_accessory.intelligence_bonus
            src.mind += src.equipped_accessory.mind_bonus
            src.vitality += src.equipped_accessory.vitality_bonus
            src.resilience += src.equipped_accessory.resilience_bonus

        // 4b. Grant skills/passives from equipped gear.
        //     Only adds a skill to gear_granted_skills if it isn't already in src.skills
        //     (i.e. the player learned it through some other means); this prevents
        //     double-adding and ensures unequip only removes what the gear itself provided.
        var/list/gear_pieces = list()
        if(src.equipped_weapon)    gear_pieces += src.equipped_weapon
        if(src.equipped_armor)     gear_pieces += src.equipped_armor
        if(src.equipped_accessory) gear_pieces += src.equipped_accessory

        for(var/datum/item/equipment/G in gear_pieces)
            var/list/grant_ids = list()
            if(G.granted_skill_ids)   grant_ids += G.granted_skill_ids
            if(G.granted_passive_ids) grant_ids += G.granted_passive_ids
            for(var/sid in grant_ids)
                var/datum/skill/GS = skill_factory.loaded_skills[sid]
                if(GS && !(GS in src.skills))
                    src.skills += GS
                    src.gear_granted_skills += GS

        // 5a. Build datum/component/affinity instances from each gear piece's
        //     damage_affinities list. These are removed and re-added every time
        //     UpdateStats() runs so equip/unequip changes take effect immediately.
        var/list/phys_types = list("Slashing", "Piercing", "Blunt", "Physical")
        for(var/datum/item/equipment/G in gear_pieces)
            if(!G.damage_affinities || !G.damage_affinities.len) continue
            for(var/dtype in G.damage_affinities)
                var/pct = G.damage_affinities[dtype]
                var/datum/component/affinity/A = new()
                A.source       = "armor"
                A.affinity_type = "Resist"   // negative pct auto-becomes vulnerability in Apply()
                A.resist_pct   = pct
                if(dtype in phys_types) A.physical_type  = dtype
                else                    A.elemental_type = dtype
                src.components += A

        // 5. Apply Passive Skill Stat Mods
        // Keys like "base_strength" map to the derived var "strength" — strip "base_" prefix.
        // Modifying base_* here would compound every UpdateStats call.
        for(var/datum/skill/S in src.equipped_skills)
            if(!S.is_passive || !S.passive_stat_mods) continue
            for(var/stat_name in S.passive_stat_mods)
                var/derived = replacetext(stat_name, "base_", "")
                if(derived in src.vars)
                    src.vars[derived] += S.passive_stat_mods[stat_name]

        src.ClampStats()
        src.ComputeTotalWeight()
        src.atb_wait = src.CalculateATBWait()

    proc/LevelUp()
        src.level++
        src.stat_points += 2
        src.max_exp = GetMaxExpForLevel(src.level)
        src << "<font color='#FFFF00'><b>*** LEVEL UP! You are now Level [src.level]! ***</b></font>"

        if(src.Primary_class)
            for(var/stat_name in src.Primary_class.stat_growths)
                var/growth_amt = src.Primary_class.stat_growths[stat_name]
                if(stat_name in src.vars)
                    src.vars[stat_name] += growth_amt
                    // Clean up the text for display (removes the word "base_")
                    var/display_name = replacetext(stat_name, "base_", "")
                    src << "<font color='#00FF00'>+ [growth_amt] [uppertext(display_name)]</font>"

            var/lvl_str = num2text(src.level)
            if(lvl_str in src.Primary_class.skill_tree)
                var/skill_path = src.Primary_class.skill_tree[lvl_str]
                var/datum/skill/new_skill = new skill_path()
                src.skills += new_skill
                src << "<font color='#00FFFF'><b>You learned a new technique: [new_skill.name]!</b></font>"

        src << "<b>You gained 2 Stat Points to spend!</b>"

        src.UpdateStats() // Apply the new stats!
        src.hp = src.max_hp
        src.mp = src.max_mp

    proc/CharacterCreation()
        src << "<font color='#FFFF00'><b>--- Welcome to the World ---</b></font>"

        var/new_name = input(src, "What is your name, hero?", "Character Creation", src.name) as text|null
        if(new_name) src.name = html_encode(new_name)

        var/list/classes = list("Novice")
        var/class_choice = input(src, "Choose your starting path.", "Class Selection") in classes

        if(class_choice == "Novice")
            src.Primary_class = new /datum/class/novice()

        src.level = 1
        src.current_exp = 0
        src.max_exp = GetMaxExpForLevel(src.level)
        src.base_max_hp = 20
        src.base_max_mp = 10
        src.base_strength = 5
        src.base_dexterity = 5
        src.base_intelligence = 5
        src.base_mind = 5
        src.base_vitality = 5
        src.base_resilience = 5
        src.stat_points = 5

        for(var/stat_name in src.Primary_class.stat_growths)
            var/growth_amt = src.Primary_class.stat_growths[stat_name]
            if(stat_name in src.vars)
                src.vars[stat_name] += growth_amt

        src.UpdateStats() // Calculate true stats
        src.hp = src.max_hp
        src.mp = src.max_mp

        src.skills += new /datum/skill/heavy_strike()


        world << "<b>[src.name]</b> has begun their journey as a <b>[src.Primary_class.name]</b>!"
        src << "<b>Creation complete! You have [src.stat_points] unspent stat points. Check the 'Tools' tab to spend them.</b>"

    proc/GainEXP(amount)
        if(amount <= 0) return
        if(src.level >= 50) return // Stop them at the level 50 cap!

        src.current_exp += amount
        src << "<font color='#00FFFF'><b>You gained [amount] EXP!</b></font>"

        // Loop just in case they gained enough EXP to level up multiple times at once
        while(src.current_exp >= src.max_exp && src.level < 50)
            src.current_exp -= src.max_exp // Keep the leftover EXP for the next level
            src.LevelUp()

    proc/GetMaxExpForLevel(lvl)
        var/list/exp_table = list(
            10,     // Level 1
            15,     // Level 2
            25,     // Level 3
            37,     // Level 4
            50,     // Level 5
            75,     // Level 6
            100,    // Level 7
            150,    // Level 8
            200,    // Level 9
            250,    // Level 10
            325,    // Level 11
            400,    // Level 12
            475,    // Level 13
            525,    // Level 14
            625,    // Level 15
            750,    // Level 16
            875,    // Level 17
            900,    // Level 18
            1000,   // Level 19
            1250,   // Level 20
            1450,   // Level 21
            1700,   // Level 22
            2000,   // Level 23
            2300,   // Level 24
            2500,   // Level 25
            2750,   // Level 26
            3000,   // Level 27
            3750,   // Level 28
            4500,   // Level 29
            5000,   // Level 30
            5500,   // Level 31
            6000,   // Level 32
            6750,   // Level 33
            7500,   // Level 34
            9000,   // Level 35
            9999,   // Level 36
            12500,  // Level 37
            15000,  // Level 38
            17500,  // Level 39
            20000,  // Level 40
            23500,  // Level 41
            27000,  // Level 42
            30000,  // Level 43
            33000,  // Level 44
            35000,  // Level 45
            38000,  // Level 46
            42000,  // Level 47
            45000,  // Level 48
            47500,  // Level 49
            50000   // Level 50
        )

        // Safety check: If they somehow pass Level 50, cap their requirement
        if(lvl > exp_table.len) return 999999

        return exp_table[lvl]