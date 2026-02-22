mob/verb
    Test_Battle()
        set category = "Debug"

        // Setup Player
        src.hp = src.max_hp
        src.is_dead = 0
        src.is_busy = 0
        src.death_threshold = -20 // TESTING NEGATIVE HP

        // Setup Dummy
        var/mob/dummy = new /mob()
        dummy.name = "Training Dummy"
        dummy.hp = 100
        dummy.spd = 5 // Slower than player
        dummy.atk = 8
        dummy.def = 2

        // Start Encounter
        var/list/P = list(src)
        var/list/E = list(dummy)
        new /datum/encounter(P, E)

        world << "<i>Debug: Fight initialized. You have a -20 Death Threshold.</i>"

    Set_Threshold(n as num)
        set category = "Debug"
        src.death_threshold = n
        src << "Your death threshold is now [n]."
mob/verb
    Party_Test_Battle()
        set category = "Debug"
        
        // 1. Setup Player
        src.hp = src.max_hp
        src.is_dead = 0
        src.is_busy = 0
        
        // 2. Setup Ally (Controlled by the AI)
        var/mob/ally = new /mob()
        ally.name = "Cleric (Ally)"
        ally.hp = 80
        ally.spd = 9 // Fast!
        ally.atk = 4
        ally.def = 5

        // 3. Setup Enemies
        var/mob/e1 = new /mob()
        e1.name = "Goblin A"
        e1.hp = 50
        e1.spd = 6
        e1.atk = 7

        var/mob/e2 = new /mob()
        e2.name = "Goblin B"
        e2.hp = 50
        e2.spd = 7
        e2.atk = 7

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