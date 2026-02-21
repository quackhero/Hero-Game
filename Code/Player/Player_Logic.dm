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

    // Notice we completely removed html += "<div class='header'>Menu</div>" 

    if(menu_state == "Main")
        html += "<div class='section-title'>==Commands==</div>"
        html += "<a href='?src=\ref[src];action=menu_attack'>Attack</a><br>"
        html += "<a href='?src=\ref[src];action=guard'>Defend</a><br>"

        html += "<div class='section-title'>==Skills==</div>"
        if(!src.equipped_skills.len)
            html += "<span style='font-size: 16px; font-style: italic;'>None</span><br>"
        else
            for(var/i = 1 to src.equipped_skills.len)
                var/datum/skill/S = src.equipped_skills[i]
                html += "<a href='?src=\ref[src];action=menu_target_skill;skill_idx=[i]'>[S.name] (Cost: [S.cost])</a><br>"

        html += "<div class='section-title'>==Items==</div>"
        if(!src.equipped_items.len)
            html += "<span style='font-size: 16px; font-style: italic;'>None</span><br>"
        else
            for(var/i = 1 to src.equipped_items.len)
                var/datum/item/I = src.equipped_items[i]
                html += "<a href='?src=\ref[src];action=menu_target_item;item_idx=[i]'>[I.name]</a><br>"

    else if(menu_state == "Target_Attack")
        html += "<div class='section-title'>==Target (Attack)==</div>"
        for(var/mob/T in E.GetEnemies(src))
            html += "<a href='?src=\ref[src];action=do_attack;target=\ref[T]'>-[T.name]-</a><br>"
        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

    else if(menu_state == "Target_Skill" && pending_skill)
        html += "<div class='section-title'>==Target ([pending_skill.name])==</div>"
        var/list/valid_targets = (pending_skill.targeting_flags & 16) ? E.GetAllies(src) : E.GetEnemies(src)
        
        if(pending_skill.targeting_flags & 2) // AOE
            html += "<a href='?src=\ref[src];action=do_skill;skill_ref=\ref[pending_skill];target=AOE'>-All Valid Targets-</a><br>"
        else
            for(var/mob/T in valid_targets)
                html += "<a href='?src=\ref[src];action=do_skill;skill_ref=\ref[pending_skill];target=\ref[T]'>-[T.name]-</a><br>"
        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

    else if(menu_state == "Target_Item" && pending_item)
        html += "<div class='section-title'>==Target ([pending_item.name])==</div>"
        for(var/mob/T in E.GetAllies(src))
            html += "<a href='?src=\ref[src];action=do_item;item_ref=\ref[pending_item];target=\ref[T]'>-[T.name]-</a><br>"
        html += "<br><a href='?src=\ref[src];action=menu_main'>-Cancel-</a><br>"

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
    if(!src.is_busy || !src.current_encounter) return 
    
    var/datum/encounter/E = src.current_encounter
    var/action = href_list["action"]

    // Navigation
    if(action == "menu_main") src.UpdateBattleMenu(E, "Main")
    else if(action == "menu_attack") src.UpdateBattleMenu(E, "Target_Attack")
    
    else if(action == "menu_target_skill")
        var/idx = text2num(href_list["skill_idx"])
        if(idx <= src.equipped_skills.len)
            var/datum/skill/S = src.equipped_skills[idx]
            if(src.mp >= S.cost) src.UpdateBattleMenu(E, "Target_Skill", S)
            else src << "Not enough MP!"

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
        src.EndTurn()

    else if(action == "do_attack")
        var/mob/T = locate(href_list["target"])
        if(T && src.CanTarget(T))
            src << browse(null, "window=battle_menu")
            src.turn_id++ 
            src.BasicAttack(T)

    else if(action == "do_skill")
        var/datum/skill/S = locate(href_list["skill_ref"])
        var/target_data = href_list["target"]
        
        src << browse(null, "window=battle_menu")
        src.turn_id++
        
        if(target_data == "AOE")
            var/list/valid = (S.targeting_flags & 16) ? E.GetAllies(src) : E.GetEnemies(src)
            S.Execute(src, valid, E)
        else
            var/mob/T = locate(target_data)
            if(T) S.Execute(src, T, E)

    else if(action == "do_item")
        var/datum/item/consumable/I = locate(href_list["item_ref"])
        var/mob/T = locate(href_list["target"])
        
        if(I && T)
            src << browse(null, "window=battle_menu")
            src.turn_id++
            if(I.Use(src, T, E))
                src.equipped_items -= I // Consume the item!
            src.EndTurn()