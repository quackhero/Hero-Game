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
    if(!item_factory.loaded_items.len)
        src << "Item factory not loaded!"
        return
    var/choice = input(src, "Which item?", "Give Item") in item_factory.loaded_items
    if(choice)
        var/datum/item/I = item_factory.MakeItem(choice)
        if(I)
            src.inventory += I
            src << "Gave you: [I.name]!"

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

// ============================================================
// DEBUG & TESTING VERBS
// ============================================================

// Instantly restores HP and MP to max, and clears dead/downed/busy flags.
// Use between tests to reset state without relogging.
mob/verb/Debug_Full_Restore()
    set category = "Debug"
    set name = "Full Restore"
    src.hp = src.max_hp
    src.mp = src.max_mp
    src.is_dead = 0
    src.is_downed = 0
    src.is_busy = 0
    src << "<b>[src.name] fully restored.</b>"

// Set HP to an exact value. Triggers ClampStats so death/downed checks fire naturally.
// Use to test: low-HP signals (SIG_HURT), death threshold, cannot-kill DoT, etc.
mob/verb/Debug_Set_HP()
    set category = "Debug"
    set name = "Set HP"
    var/new_hp = input(src, "Set HP to (max: [src.max_hp]):", "Set HP") as num|null
    if(isnull(new_hp)) return
    src.hp = new_hp
    src.ClampStats()
    src << "<b>HP set to [src.hp].</b>"

// Set MP to an exact value. Use to test: CanAct MP check, mana shield, AI MP items.
mob/verb/Debug_Set_MP()
    set category = "Debug"
    set name = "Set MP"
    var/new_mp = input(src, "Set MP to (max: [src.max_mp]):", "Set MP") as num|null
    if(isnull(new_mp)) return
    src.mp = clamp(new_mp, 0, src.max_mp)
    src << "<b>MP set to [src.mp].</b>"

// Set any base_* stat and recalculate derived stats via UpdateStats().
// Use to test: damage formulas, ATB speed (dexterity), resist mitigation, etc.
mob/verb/Debug_Set_Stat()
    set category = "Debug"
    set name = "Set Stat"
    var/list/stat_list = list(
        "base_max_hp", "base_max_mp",
        "base_strength", "base_resilience", "base_dexterity",
        "base_intelligence", "base_mind", "base_vitality"
    )
    var/stat = input(src, "Which base stat to set?", "Set Stat") in stat_list
    if(!stat) return
    var/new_val = input(src, "Set [stat] to:", "Set Stat") as num|null
    if(isnull(new_val)) return
    src.vars[stat] = new_val
    src.UpdateStats()
    src << "<b>[stat] = [new_val]. Stats recalculated.</b>"

// Apply any status from Statuses.json to yourself or any encounter participant.
// Use to test: all 83+ statuses, DoT/HoT, CC, stat mods, positional states, Re-Raise, etc.
mob/verb/Debug_Apply_Status()
    set category = "Debug"
    set name = "Apply Status"
    if(!status_factory || !status_factory.loaded_statuses.len)
        src << "No statuses loaded!"
        return

    var/list/target_options = list("Self")
    if(src.current_encounter)
        for(var/mob/M in src.current_encounter.all_participants)
            if(M != src) target_options += M

    var/target_pick = input(src, "Apply status to:", "Choose Target") in target_options
    if(isnull(target_pick)) return
    var/mob/T = (target_pick == "Self") ? src : target_pick

    var/sid = input(src, "Which status?", "Choose Status") in status_factory.loaded_statuses
    if(!sid) return

    var/dur = input(src, "Duration (turns)?", "Duration") as num|null
    if(isnull(dur)) return

    var/amt = input(src, "Amount (0 if unused):", "Amount") as num|null
    if(isnull(amt)) amt = 0

    T.ApplyStatus(sid, dur, amt)

// Remove a specific status or all statuses from yourself.
// Use to test: OnRemove stat restoration, positional flag cleanup, Berserk RES restore, etc.
mob/verb/Debug_Remove_Status()
    set category = "Debug"
    set name = "Remove Status"
    var/list/active_statuses = list()
    for(var/datum/component/status/C in src.components)
        active_statuses += C
    if(!active_statuses.len)
        src << "No active statuses to remove."
        return
    var/list/options = list("-- Remove All --") + active_statuses
    var/choice = input(src, "Remove which?", "Remove Status") in options
    if(!choice) return
    if(choice == "-- Remove All --")
        for(var/datum/component/status/C in src.components.Copy())
            src.RemoveStatus(C)
    else
        src.RemoveStatus(choice)

// Directly set your positional state without applying a status.
// Use to test: CanTarget filtering, AI targeting, menu target list exclusion, mutual exclusion.
mob/verb/Debug_Set_Position()
    set category = "Debug"
    set name = "Set Position"
    var/pos = input(src, "Set positional state:", "Set Position") in list("Grounded", "Airborne", "Burrowed")
    if(!pos) return
    src.is_aerial_target = 0
    src.is_burrowed = 0
    switch(pos)
        if("Airborne") src.is_aerial_target = 1
        if("Burrowed") src.is_burrowed = 1
    src << "<b>Position set to [pos].</b>"

// Manually fire any signal on yourself.
// Use to test: trigger skills, passive triggers, Re-Raise (SIG_DYING), SIG_KILL, trigger_once, etc.
mob/verb/Debug_Fire_Signal()
    set category = "Debug"
    set name = "Fire Signal"
    var/list/signal_list = list(
        "ON_TURN_START", "ON_TURN_END",
        "SIG_DOWNED", "SIG_HURT", "SIG_FULL_HP", "SIG_ALONE", "SIG_WAIT",
        "SIG_DAMAGED", "SIG_DEALT_DAMAGE",
        "SIG_DYING", "SIG_DEATH", "SIG_KILL",
        "SIG_STATUS_APPLIED", "SIG_STATUS_REMOVED"
    )
    var/sig = input(src, "Fire which signal on yourself?", "Fire Signal") in signal_list
    if(!sig) return
    src.SendSignal(sig)
    src << "<b>Signal fired: [sig]</b>"

// Start a battle with a chosen enemy type and count. Auto-restores you first.
// Use to test: ATB order, AI behavior, EXP calculation, positional targeting, multi-enemy AOE, etc.
mob/verb/Debug_Custom_Battle()
    set category = "Debug"
    set name = "Custom Battle"
    if(src.current_encounter)
        src << "You are already in a battle!"
        return

    var/etype = input(src, "Enemy type?", "Enemy Type") in list("Training Dummy (10 HP)", "Striking Dummy (500 HP)")
    var/ecount = input(src, "Number of enemies? (1-4)", "Enemy Count") in list("1", "2", "3", "4")
    var/want_ally = input(src, "Include an AI ally?", "Ally") in list("No", "Yes")

    src.hp = src.max_hp
    src.mp = src.max_mp
    src.is_dead = 0
    src.is_downed = 0
    src.is_busy = 0

    var/list/enemy_list = list()
    for(var/i = 1 to text2num(ecount))
        var/mob/enemy/E
        if(etype == "Training Dummy (10 HP)")
            E = new /mob/enemy/training_dummy()
        else
            E = new /mob/enemy/active_dummy()
        enemy_list += E

    var/list/player_list = list(src)
    if(want_ally == "Yes")
        var/mob/M = new /mob()
        M.name = "AI Ally"
        M.hp = 100
        M.max_hp = 100
        M.mp = 50
        M.max_mp = 50
        M.strength = 10
        M.resilience = 5
        M.dexterity = 8
        player_list += M

    new /datum/encounter(player_list, enemy_list)
    src << "<b>Custom battle: [ecount]x [etype] started.</b>"

// Award a specific amount of EXP. Use to test leveling, EXP floor, anti-grind scaling.
mob/verb/Debug_Give_EXP()
    set category = "Debug"
    set name = "Give EXP"
    var/amount = input(src, "How much EXP to award?", "Give EXP") as num|null
    if(isnull(amount) || amount <= 0) return
    src.GainEXP(amount)

// Instantly kill a living mob in the current encounter.
// Use to test: SIG_KILL triggers, HandleDeath flow, AI dead-target filtering, on_target_death.
mob/verb/Debug_Kill_Target()
    set category = "Debug"
    set name = "Kill Target"
    if(!src.current_encounter)
        src << "Not currently in an encounter."
        return
    var/list/candidates = list()
    for(var/mob/M in src.current_encounter.all_participants)
        if(!M.is_dead) candidates += M
    if(!candidates.len)
        src << "No living targets in the encounter."
        return
    var/mob/T = input(src, "Kill which mob?", "Kill Target") in candidates
    if(!T) return
    T.TakeDamage(99999, src, "True", 0)

// Print a full debug snapshot of your current state to chat.
// Use at any point to verify stats, active statuses, position, and encounter state.
mob/verb/Debug_View_State()
    set category = "Debug"
    set name = "View State"
    src << "<b>===== [src.name] Debug State =====</b>"
    src << "HP: [src.hp] / [src.max_hp] | MP: [src.mp] / [src.max_mp]"
    src << "STR: [src.strength] | DEX: [src.dexterity] | RES: [src.resilience]"
    src << "INT: [src.intelligence] | MND: [src.mind] | VIT: [src.vitality]"
    src << "Position: [src.GetPositionalState()] | Vanished: [src.is_vanished]"
    src << "Dead: [src.is_dead] | Downed: [src.is_downed] | Busy: [src.is_busy] | Defending: [src.defending]"
    src << "ATB: [src.atb_gauge] / [ATB_GAUGE_MAX]"
    if(src.components.len)
        src << "<b>--- Active Components ([src.components.len]) ---</b>"
        for(var/datum/component/C in src.components)
            src << "&nbsp;&nbsp;> [C.name] | dur: [C.duration] | amt: [C.amount]"
    else
        src << "No active components."
    src << "Encounter: [src.current_encounter ? "Active" : "None"]"
    src << "<b>===================================</b>"