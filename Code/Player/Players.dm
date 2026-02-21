mob
    var/datum/class/Primary_class
    var/current_exp = 0
    var/max_exp = 100 
    var/level = 1
    var/stat_points = 0 

    // --- NEW: INVENTORY & EQUIPMENT ---
    var/list/inventory = list()
    var/datum/item/equipment/equipped_weapon
    var/datum/item/equipment/equipped_armor
    var/datum/item/equipment/equipped_accessory

    // --- NEW: BASE STATS (Naked Stats) ---
    var/base_max_hp = 100
    var/base_max_mp = 50
    var/base_atk = 10
    var/base_def = 10
    var/base_spd = 10
    var/base_ap = 10

    // --- THE MATH ENGINE ---
    proc/UpdateStats()
        // 1. Reset to naked stats
        src.max_hp = src.base_max_hp
        src.max_mp = src.base_max_mp
        src.atk = src.base_atk
        src.def = src.base_def
        src.spd = src.base_spd
        src.ap = src.base_ap

        // 2. Add Weapon Stats
        if(src.equipped_weapon)
            src.max_hp += src.equipped_weapon.max_hp_bonus
            src.max_mp += src.equipped_weapon.max_mp_bonus
            src.atk += src.equipped_weapon.atk_bonus
            src.def += src.equipped_weapon.def_bonus
            src.spd += src.equipped_weapon.spd_bonus

        // 3. Add Armor Stats
        if(src.equipped_armor)
            src.max_hp += src.equipped_armor.max_hp_bonus
            src.max_mp += src.equipped_armor.max_mp_bonus
            src.atk += src.equipped_armor.atk_bonus
            src.def += src.equipped_armor.def_bonus
            src.spd += src.equipped_armor.spd_bonus
            
        // 4. Add Accessory Stats
        if(src.equipped_accessory)
            src.max_hp += src.equipped_accessory.max_hp_bonus
            src.max_mp += src.equipped_accessory.max_mp_bonus
            src.atk += src.equipped_accessory.atk_bonus
            src.def += src.equipped_accessory.def_bonus
            src.spd += src.equipped_accessory.spd_bonus

        src.ClampStats()

    proc/LevelUp()
        src.level++
        src.stat_points += 2 
        
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
        src.base_max_hp = 20
        src.base_max_mp = 10
        src.base_atk = 5
        src.base_def = 5
        src.base_spd = 5
        src.base_ap = 5
        src.stat_points = 5 

        for(var/stat_name in src.Primary_class.stat_growths)
            var/growth_amt = src.Primary_class.stat_growths[stat_name]
            if(stat_name in src.vars)
                src.vars[stat_name] += growth_amt

        src.UpdateStats() // Calculate true stats
        src.hp = src.max_hp
        src.mp = src.max_mp
        
        src.skills += new /datum/skill/heavy_strike()
        src.skills += new /datum/skill/cure()

        world << "<b>[src.name]</b> has begun their journey as a <b>[src.Primary_class.name]</b>!"
        src << "<b>Creation complete! You have [src.stat_points] unspent stat points. Check the 'Tools' tab to spend them.</b>"