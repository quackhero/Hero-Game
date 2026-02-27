/**
 * PLAYER LOGIC (HTML MENU VERSION)
 * Handles the single-page Tactical Loadout, Topic clicks, and Turn Timers.
 */

mob/proc/UpdateBattleMenu(datum/encounter/E, menu_state = "Main", datum/skill/pending_skill = null, datum/item/pending_item = null)
    var/html = {"
    <html><head>
    <title>Menu</title> <style>
        body { margin: 0px; padding: 0px; font-family: 'Times New Roman', serif; background-color: #c0c0c0; text-align: center; color: #800080; font-weight: bold; font-size: 18px; }
        .header { background-color: #000022; color: #FFCC00; padding: 6px 10px; text-align: left; }
        a { color: #800080; text-decoration: none; }
        a:hover { background-color: #00FFFF; text-decoration: none; }
        .section-title { margin-top: 10px; margin-bottom: 2px; }
    </style></head><body topmargin="0" leftmargin="0" rightmargin="0">
    "}

    if(menu_state == "Main")
        html += "<div class='section-title'>==Commands==</div>"
        html += "<a href='?src=\ref[src];action=menu_attack'>Attack</a><br>"
        html += "<a href='?src=\ref[src];action=guard'>Defend</a><br>"

        html += "<div class='section-title'>==Skills==</div>"
        if(!src.equipped_skills.len)
            html += "<span style='font-size: 16px; font-style: italic;'>None</span><br>"
        else
            var/any_active = 0
            for(var/i = 1 to src.equipped_skills.len)
                var/datum/skill/S = src.equipped_skills[i]
                if(S.is_passive) continue // Passives are hidden during battle
                any_active = 1
                html += "<a href='?src=\ref[src];action=menu_target_skill;skill_idx=[i]'>[S.name] (Cost: [S.cost])</a><br>"
            if(!any_active)
                html += "<span style='font-size: 16px; font-style: italic;'>None</span><br>"

        html += "<div class='section-title'>==Items==</div>"
        if(!src.equipped_items.len)
            html += "<span style='font-size: 16px; font-style: italic;'>None</span><br>"
        else
            for(var/i = 1 to src.equipped_items.len)
                var/datum/item/I = src.equipped_items[i]
                html += "<a href='?src=\ref[src];action=menu_target_item;item_idx=[i]'>[I.name]</a><br>"

    else if(menu_state == "Target_Attack")
        html += "<div class='section-title'>==Target (Attack)==</div>"
        var/datum/skill/atk_skill = skill_factory.loaded_skills["basic_attack"]
        for(var/mob/T in E.GetEnemies(src))
            if(src.CanTarget(T, atk_skill, 1)) // silent=1: no error spam in the menu
                html += "<a href='?src=\ref[src];action=do_attack;target=\ref[T]'>-[T.name]-</a><br>"
        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

    else if(menu_state == "Target_Skill" && pending_skill)
        html += "<div class='section-title'>==Target ([pending_skill.name])==</div>"

        var/list/valid_targets = (pending_skill.targeting_flags & (TARGET_HEAL | TARGET_REVIVE)) ? E.GetAllies(src) : E.GetEnemies(src)

        for(var/mob/T in valid_targets)
            // Both positional reachability AND skill-specific requirements must pass.
            if(src.CanTarget(T, pending_skill, 1) && pending_skill.IsValidTarget(src, T))
                html += "<a href='?src=\ref[src];action=do_skill;skill_ref=\ref[pending_skill];target=\ref[T]'>-[T.name]-</a><br>"

        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

    else if(menu_state == "Target_Item" && pending_item)
        html += "<div class='section-title'>==Target ([pending_item.name])==</div>"
        for(var/mob/T in E.GetAllies(src))
            html += "<a href='?src=\ref[src];action=do_item;item_ref=\ref[pending_item];target=\ref[T]'>-[T.name]-</a><br>"
        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

    // --- NEW: THE COMBO MENU ---
    else if(menu_state == "Combo_Select" && pending_skill)
        html += "<div class='section-title'>==Combo Finish!==</div>"
        
        var/mob/combo_t = src.active_combo_targets[1]
        var/target_name = (src.active_combo_targets.len > 1) ? "Multiple Targets" : (combo_t ? combo_t.name : "Unknown")
        html += "<span class='stat-text'>Juggling: [target_name]</span><br><br>"
        
        for(var/branch_id in pending_skill.combo_branches)
            var/datum/skill/branch_skill = skill_factory.loaded_skills[branch_id]
            if(branch_skill)
                html += "<a href='?src=\ref[src];action=do_combo;skill_id=[branch_id]'>-[branch_skill.name]- (Cost: [branch_skill.cost])</a><br>"
                
        html += "<br><a href='?src=\ref[src];action=end_combo'>-End Combo-</a><br>"

    html += "</body></html>"
    
    src << browse(html, "window=battle_menu;size=250x450;can_close=0;can_resize=0")


// The override for player turns
mob/TakeAction(datum/encounter/E)
    if(!src.client) return ..() 

    src.defending = 0 
    src.turn_id++ // Increment the unique turn ID
    var/current_turn = src.turn_id
    
    src.UpdateBattleMenu(E, "Main")
    
    // --- THE TURN TIMER ---
    spawn(150) // 15 seconds
        if(src && src.turn_id == current_turn && src.is_busy)
            src << browse(null, "window=battle_menu") 
            src.defending = 1
            world << "<i>[src.name] hesitates and defaults to defending!</i>"
            src.EndTurn()


// --- THE CLICK CATCHER ---
mob/Topic(href, href_list)
    ..()
    var/action = href_list["action"]
    
    // ==========================================
    // OUT-OF-COMBAT MENU LOGIC
    // ==========================================
    if(action == "camp_close")
        src << browse(null, "window=camp_menu")
        return
    else if(action == "camp_main")
        src.UpdateMainMenu("Main")
        return
        
    // --- Navigation ---
    else if(action == "camp_equip")
        src.UpdateMainMenu("Equip_Gear", href_list["slot"])
        return
    else if(action == "camp_skill")
        src.UpdateMainMenu("Equip_Skill", null, text2num(href_list["slot_idx"]))
        return
    else if(action == "camp_item")
        src.UpdateMainMenu("Equip_Item", null, text2num(href_list["slot_idx"]))
        return

    // --- Equipping Gear ---
    else if(action == "do_camp_equip")
        var/slot = href_list["slot"]
        var/datum/item/equipment/E = locate(href_list["item_ref"])
        if(E && (E in src.inventory))
            if(slot == "Weapon") src.equipped_weapon = E
            else if(slot == "Armor") src.equipped_armor = E
            else if(slot == "Accessory") src.equipped_accessory = E
            src.UpdateStats() // Recalculate stats immediately!
        src.UpdateMainMenu("Main")
        return
        
    else if(action == "do_camp_unequip")
        var/slot = href_list["slot"]
        if(slot == "Weapon") src.equipped_weapon = null
        else if(slot == "Armor") src.equipped_armor = null
        else if(slot == "Accessory") src.equipped_accessory = null
        src.UpdateStats() // Recalculate stats without the gear
        src.UpdateMainMenu("Main")
        return

    // --- Equipping Skills & Items ---
    else if(action == "do_camp_equip_skill")
        var/idx = text2num(href_list["slot_idx"])
        var/datum/skill/S = locate(href_list["skill_ref"])
        if(S && (S in src.skills))
            if(idx <= src.equipped_skills.len) src.equipped_skills[idx] = S // Swap it
            else src.equipped_skills += S // Add it
        src.UpdateStats() // Recalculate stats in case a passive was equipped
        src.UpdateMainMenu("Main")
        return

    else if(action == "do_camp_unequip_skill")
        var/idx = text2num(href_list["slot_idx"])
        if(idx <= src.equipped_skills.len)
            src.equipped_skills -= src.equipped_skills[idx] // Cleanly removes it
        src.UpdateStats() // Recalculate stats in case a passive was removed
        src.UpdateMainMenu("Main")
        return
        
    else if(action == "do_camp_equip_item")
        var/idx = text2num(href_list["slot_idx"])
        var/datum/item/consumable/I = locate(href_list["item_ref"])
        if(I && (I in src.inventory))
            if(idx <= src.equipped_items.len) src.equipped_items[idx] = I
            else src.equipped_items += I
        src.UpdateMainMenu("Main")
        return
        
    else if(action == "do_camp_unequip_item")
        var/idx = text2num(href_list["slot_idx"])
        if(idx <= src.equipped_items.len)
            src.equipped_items -= src.equipped_items[idx]
        src.UpdateMainMenu("Main")
        return


    // ==========================================
    // COMBAT MENU LOGIC 
    // ==========================================
    if(!src.is_busy || !src.current_encounter) return 
    
    var/datum/encounter/E = src.current_encounter

    // Navigation
    if(action == "menu_main") src.UpdateBattleMenu(E, "Main")
    else if(action == "menu_attack") src.UpdateBattleMenu(E, "Target_Attack")
    
    else if(action == "menu_target_skill")
        var/idx = text2num(href_list["skill_idx"])
        if(idx <= src.equipped_skills.len)
            var/datum/skill/S = src.equipped_skills[idx]
            
            if(src.mp >= S.cost)
                // 1. SELF CAST (Bypass Menu)
                if(S.targeting_flags & TARGET_SELF)
                    src << browse(null, "window=battle_menu") 
                    src.is_busy = 0
                    src.turn_id++
                    S.Execute(src, src, E)
                    
                // 2. AOE CAST (Bypass Menu & Grab All Valid Targets)
                else if(S.targeting_flags & TARGET_AOE)
                    src << browse(null, "window=battle_menu") 
                    src.is_busy = 0
                    src.turn_id++
                    
                    var/list/potential_targets = (S.targeting_flags & (TARGET_HEAL | TARGET_REVIVE)) ? E.GetAllies(src) : E.GetEnemies(src)
                    var/list/valid_targets = list()

                    for(var/mob/M in potential_targets)
                        // Positional reachability check (silent) + skill requirements
                        if(src.CanTarget(M, S, 1) && S.IsValidTarget(src, M))
                            valid_targets += M
                            
                    if(!valid_targets.len)
                        src << "<i>There are no valid targets to hit!</i>"
                        src.EndTurn()
                    else
                        S.Execute(src, valid_targets, E)
                        
                // 3. SINGLE TARGET (Open Target Selection Menu)
                else
                    src.UpdateBattleMenu(E, "Target_Skill", S)
            else
                src << "Not enough MP!"

    else if(action == "menu_target_item")
        var/idx = text2num(href_list["item_idx"])
        if(idx <= src.equipped_items.len)
            src.UpdateBattleMenu(E, "Target_Item", null, src.equipped_items[idx])

    // Actions
    else if(action == "guard")
        src << browse(null, "window=battle_menu")
        src.defending = 1
        world << "<i>[src.name] braces for impact!</i>"
        src.turn_id++
        src.SendSignal("SIG_WAIT")
        src.EndTurn()

    else if(action == "do_attack")
        var/mob/T = locate(href_list["target"])
        var/datum/skill/atk = skill_factory.loaded_skills["basic_attack"]
        if(T && src.CanTarget(T, atk))
            src << browse(null, "window=battle_menu")
            src.turn_id++
            src.is_busy = 0
            src.BasicAttack(T)

    else if(action == "do_skill")
        var/datum/skill/S = locate(href_list["skill_ref"])
        var/target_data = href_list["target"]
        var/mob/T = locate(target_data)

        if(S && T && src.CanTarget(T, S))
            src << browse(null, "window=battle_menu")
            src.is_busy = 0
            src.turn_id++
            S.Execute(src, T, E)

    // --- NEW: COMBO ACTIONS ---
    else if(action == "do_combo")
        var/skill_id = href_list["skill_id"]
        var/datum/skill/S = skill_factory.loaded_skills[skill_id]
        
        if(S && src.active_combo_targets)
            if(src.mp >= S.cost)
                src << browse(null, "window=battle_menu")
                
                // Grab the target(s) we stored
                var/combo_targets = (src.active_combo_targets.len == 1) ? src.active_combo_targets[1] : src.active_combo_targets
                src.active_combo_targets = null // Clear memory
                
                // Execute the branch! 
                S.Execute(src, combo_targets, E) 
            else
                src << "Not enough MP to finish the combo!"

    else if(action == "end_combo")
        src << browse(null, "window=battle_menu")
        src.active_combo_targets = null
        src.is_busy = 0
        src.EndTurn() // They chose to drop the combo

    else if(action == "do_item")
        var/datum/item/consumable/I = locate(href_list["item_ref"])
        var/mob/T = locate(href_list["target"])
        
        if(I && T)
            src << browse(null, "window=battle_menu")
            src.is_busy = 0
            src.turn_id++
            if(I.Use(src, T, E))
                src.equipped_items -= I // Consume the item!
            src.EndTurn()


mob/proc/UpdateMainMenu(menu_state = "Main", target_slot = null, target_idx = 0)
    var/html = {"
    <html><head>
    <title>Menu</title>
    <style>
        body { margin: 0px; padding: 0px; font-family: 'Times New Roman', serif; background-color: #c0c0c0; text-align: center; color: #800080; font-weight: bold; font-size: 18px; }
        .header { background-color: #000022; color: #FFCC00; padding: 6px 10px; text-align: left; }
        a { color: #800080; text-decoration: none; }
        a:hover { background-color: #00FFFF; text-decoration: none; }
        .section-title { margin-top: 10px; margin-bottom: 2px; }
        .stat-text { color: #000000; font-size: 16px; font-weight: normal; }
    </style></head><body topmargin="0" leftmargin="0" rightmargin="0">
    "}

    if(menu_state == "Main")
        html += "<div class='header'>[src.name] - Lvl [src.level]</div>"
        html += "<div class='stat-text'>HP: [src.hp]/[src.max_hp] | MP: [src.mp]/[src.max_mp]<br>"
        
        // --- NEW SIX-STAT DISPLAY ---
        html += "STR: [src.strength] | DEX: [src.dexterity] | INT: [src.intelligence]<br>"
        html += "MND: [src.mind] | VIT: [src.vitality] | RES: [src.resilience]</div>"

        html += "<div class='section-title'>==Equipment==</div>"
        html += "<a href='?src=\ref[src];action=camp_equip;slot=Weapon'>Weapon: [(src.equipped_weapon ? src.equipped_weapon.name : "None")]</a><br>"
        html += "<a href='?src=\ref[src];action=camp_equip;slot=Armor'>Armor: [(src.equipped_armor ? src.equipped_armor.name : "None")]</a><br>"
        html += "<a href='?src=\ref[src];action=camp_equip;slot=Accessory'>Accessory: [(src.equipped_accessory ? src.equipped_accessory.name : "None")]</a><br>"

        html += "<div class='section-title'>==Skills==</div>"
        for(var/i = 1 to src.max_skill_slots)
            if(i <= src.equipped_skills.len)
                var/datum/skill/S = src.equipped_skills[i]
                var/passive_tag = S.is_passive ? " \[Passive\]" : ""
                html += "<a href='?src=\ref[src];action=camp_skill;slot_idx=[i]'>Slot [i]: [S.name][passive_tag]</a><br>"
            else
                html += "<a href='?src=\ref[src];action=camp_skill;slot_idx=[i]'>Slot [i]: -Empty-</a><br>"

        html += "<div class='section-title'>==Items==</div>"
        for(var/i = 1 to src.max_item_slots)
            if(i <= src.equipped_items.len)
                var/datum/item/I = src.equipped_items[i]
                html += "<a href='?src=\ref[src];action=camp_item;slot_idx=[i]'>Belt [i]: [I.name]</a><br>"
            else
                html += "<a href='?src=\ref[src];action=camp_item;slot_idx=[i]'>Belt [i]: -Empty-</a><br>"

    // --- SUB-MENUS ---
    else if(menu_state == "Equip_Gear")
        html += "<div class='section-title'>==Equip [target_slot]==</div>"
        html += "<a href='?src=\ref[src];action=do_camp_unequip;slot=[target_slot]'>-(Remove Current)-</a><br><br>"
        var/found = 0
        for(var/datum/item/equipment/E in src.inventory)
            if(E.item_type == target_slot)
                found = 1
                html += "<a href='?src=\ref[src];action=do_camp_equip;slot=[target_slot];item_ref=\ref[E]'>[E.name]</a><br>"
        if(!found) html += "<span class='stat-text'>No [target_slot]s in inventory.</span><br>"
        html += "<br><a href='?src=\ref[src];action=camp_main'>-Cancel-</a>"

    else if(menu_state == "Equip_Skill")
        html += "<div class='section-title'>==Equip to Slot [target_idx]==</div>"
        html += "<a href='?src=\ref[src];action=do_camp_unequip_skill;slot_idx=[target_idx]'>-(Clear Slot)-</a><br><br>"
        var/found = 0
        for(var/datum/skill/S in src.skills)
            if(!(S in src.equipped_skills)) // Don't show skills already equipped
                found = 1
                var/passive_tag = S.is_passive ? " \[Passive\]" : ""
                html += "<a href='?src=\ref[src];action=do_camp_equip_skill;slot_idx=[target_idx];skill_ref=\ref[S]'>[S.name][passive_tag]</a><br>"
        if(!found) html += "<span class='stat-text'>No available skills.</span><br>"
        html += "<br><a href='?src=\ref[src];action=camp_main'>-Cancel-</a>"

    else if(menu_state == "Equip_Item")
        html += "<div class='section-title'>==Equip to Belt [target_idx]==</div>"
        html += "<a href='?src=\ref[src];action=do_camp_unequip_item;slot_idx=[target_idx]'>-(Clear Slot)-</a><br><br>"
        var/found = 0
        for(var/datum/item/consumable/I in src.inventory)
            if(!(I in src.equipped_items)) 
                found = 1
                html += "<a href='?src=\ref[src];action=do_camp_equip_item;slot_idx=[target_idx];item_ref=\ref[I]'>[I.name]</a><br>"
        if(!found) html += "<span class='stat-text'>No available consumables.</span><br>"
        html += "<br><a href='?src=\ref[src];action=camp_main'>-Cancel-</a>"

    html += "</body></html>"
    src << browse(html, "window=camp_menu;size=250x450;can_close=1;can_resize=0")