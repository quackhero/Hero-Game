mob
    verb
        change_name()
            set category = "Tools"
            set name = "Change Name"
            var/new_name = input(src, "What would you like to be called?", "Name Change", src.name) as text|null
            if(!new_name) return
            var/old_name = src.name
            src.name = html_encode(new_name)
            world << "<b>[old_name]</b> is now known as <b>[src.name]</b>."
        spend_stat_points()
            set category = "Tools"
            set name = "Spend Stat Points"
            
            if(src.stat_points <= 0)
                src << "You have no stat points to spend."
                return
            
            // Changed to match the new base_ variable names
            var/list/options = list("base_max_hp", "base_max_mp", "base_atk", "base_def", "base_spd", "base_ap", "Cancel")
            
            var/choice = input(src, "You have [src.stat_points] points. Which stat would you like to increase by 1?", "Stat Allocation") in options
            if(choice == "Cancel") return
            
            if(src.stat_points <= 0) return 

            src.vars[choice] += 1
            src.stat_points -= 1
            
            // Recalculate true stats immediately
            src.UpdateStats()
            
            var/display_name = replacetext(choice, "base_", "")
            src << "<b>You increased your [uppertext(display_name)]! ([src.stat_points] points remaining)</b>"

mob/verb/Debug_Level_Up()
    set category = "Debug"
    // Give ourselves the Novice class if we don't have it
    if(!src.Primary_class) src.Primary_class = new /datum/class/novice()
    src.LevelUp()

mob/verb/Open_Menu()
    set category = "Commands"
    set name = "Menu"
    if(src.current_encounter)
        src << "You can't do this in battle!"
        return
    src.UpdateMainMenu("Main")