var/list/global_main_party = list()

mob/verb/Party_Test_Battle()
    set category = "Debug"
    
    // 1. Setup Player
    src.hp = src.max_hp
    src.is_dead = 0
    src.is_busy = 0
    
    // 2. Setup Ally (Controlled by the AI)
    var/mob/ally = new /mob()
    ally.name = "Cleric (Ally)"
    ally.hp = 1
    ally.dexterity = 9 // Fast! (Was spd)
    ally.strength = 4  // (Was atk)
    ally.resilience = 5 // (Was def)

    // 3. Setup Enemies
    var/mob/e1 = new /mob()
    e1.name = "Goblin A"
    e1.hp = 50
    e1.race = "Goblin"
    e1.dexterity = 6 // (Was spd)
    e1.strength = 7  // (Was atk)

    var/mob/e2 = new /mob()
    e2.name = "Goblin B"
    e2.race = "Goblin"
    e2.hp = 50
    e2.dexterity = 7 // (Was spd)
    e2.strength = 7  // (Was atk)

    // 4. Start the 2v2 Encounter
    var/list/P = list(src, ally)
    var/list/E = list(e1, e2)
    new /datum/encounter(P, E)
    
    world << "<b>Debug: 2v2 Party Battle Initialized!</b>"

mob/verb/Test_Give_Item()
    set category = "Admin"
    var/datum/item/equipment/weapon/iron_sword/W = new()
    src.inventory += W
    src << "Gave you an [W.name]!"

mob/verb/Main_Party()
    set category = "Admin"
    var/action = input(src, "What would you like to do with the party?", "Main Party") in list("Add Player", "Remove Player", "View Party", "Clear Party", "Cancel")
    
    switch(action)
        if("Add Player")
            var/list/candidates = list()
            for(var/mob/M in world)
                // We filter for players with clients who aren't in the party yet
                if(M.client && !(M in global_main_party))
                    candidates += M
            
            if(!candidates.len)
                src << "No other players online to add."
                return
            
            // FIXED: Removed 'as mob|null' since the list handles the filtering natively
            var/mob/choice = input(src, "Select a player to add:", "Add Player") in candidates
            if(choice)
                global_main_party += choice
                world << "<b>[choice.name] has been added to the Main Party.</b>"

        if("Remove Player")
            if(!global_main_party.len) return
            
            // FIXED: Removed 'as mob|null'
            var/mob/choice = input(src, "Select a player to remove:", "Remove Player") in global_main_party
            if(choice)
                global_main_party -= choice
                world << "<b>[choice.name] has been removed from the Main Party.</b>"

        if("View Party")
            if(!global_main_party.len)
                src << "The party is currently empty."
            else
                src << "<b>--- Current Main Party ---</b>"
                for(var/mob/M in global_main_party)
                    src << "- [M.name] (Level [M.level])"

        if("Clear Party")
            global_main_party.Cut()
            world << "<b>The Main Party has been cleared.</b>"

mob/verb/Start_Party_Encounter()
    set category = "Admin"
    if(!global_main_party.len)
        src << "The Main Party is empty! Add members first."
        return

    // Setup Enemies (Using your training dummy type)
    var/mob/enemy/E1 = new /mob/enemy/training_dummy()
    var/mob/enemy/E2 = new /mob/enemy/training_dummy()
    
    var/list/Enemies = list(E1, E2)
    
    // Launch the encounter using the admin-defined party
    new /datum/encounter(global_main_party, Enemies)
    
    world << "<b>Admin: Starting encounter for the Main Party!</b>"

mob/verb/Give_JSON_Skill()
    set category = "Admin"
    
    // Check if the factory actually loaded anything
    if(!skill_factory.loaded_skills.len)
        src << "No JSON skills are currently loaded!"
        return
        
    // Pop up a list of all loaded skill IDs
    var/choice = input(src, "Which skill do you want to learn?", "Give Skill") in skill_factory.loaded_skills
    
    if(choice)
        // Grab the skill from the factory and give it to the player
        var/datum/skill/S = skill_factory.loaded_skills[choice]
        src.skills += S
        src << "<font color='#00FFFF'><b>You learned [S.name]!</b></font>"

mob/verb/Test_Dummy_Fight()
    set category = "Admin"
    var/mob/enemy/active_dummy/D = new()
    
    // FIXED: Put them in lists and pass them directly to the encounter!
    var/list/P = list(src)
    var/list/E = list(D)
    
    new /datum/encounter(P, E)