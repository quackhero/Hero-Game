datum/encounter
    var/list/players = list()
    var/list/enemies = list()
    var/list/all_participants = list()
    var/is_active = 0
    var/tick_rate = 2 // Slightly slower for text readability

    New(list/P, list/E)
        src.players = P
        src.enemies = E
        src.all_participants = P + E
        for(var/mob/M in src.all_participants)
            M.current_encounter = src
            M.atb_gauge = 0 
        src.Start()

    proc/Start()
        src.is_active = 1
        world << "<b>*** BATTLE START ***</b>"
        src.CombatLoop()

    proc/CombatLoop()
        spawn(0)
            while(src.is_active)
                for(var/mob/M in src.all_participants)
                    // Supports Negative HP/Death Thresholds and prevents double turns
                    if(M.is_dead || M.hp <= M.death_threshold || M.is_busy) continue

                    M.atb_gauge += (M.spd + 1)
                    
                    if(M.atb_gauge >= ATB_GAUGE_MAX)
                        M.atb_gauge = ATB_GAUGE_MAX
                        world << "<small>*** [M.name] is ready! ***</small>"
                        src.ExecuteTurn(M)

                sleep(src.tick_rate)

    proc/ExecuteTurn(mob/M)
        M.is_busy = 1
        // spawn(0) prevents a player's menu selection from freezing the entire battle clock
        spawn(0)
            M.ReadyTurn()

    proc/GetEnemies(mob/looker)
        return (looker in src.players) ? src.enemies : src.players

    // Added to allow Skills (like Cure) to target teammates
    proc/GetAllies(mob/looker)
        return (looker in src.players) ? src.players : src.enemies

    proc/CheckStatus()
        var/p_alive = 0
        var/e_alive = 0
        for(var/mob/M in src.players) if(!M.is_dead) p_alive++
        for(var/mob/M in src.enemies) if(!M.is_dead) e_alive++
        
        if(e_alive <= 0) src.EndBattle("Victory")
        else if(p_alive <= 0) src.EndBattle("Defeat")

    proc/EndBattle(result)
        src.is_active = 0
        world << "<b>Combat Result: [result]</b>"
        for(var/mob/M in src.all_participants)
            M.atb_gauge = 0
            M.is_busy = 0
            M.current_encounter = null
        for(var/mob/M in src.all_participants) // (or whatever your list of fighters is called)
            if(M.client) // Only check real players
                M << browse(null, "window=battle_menu")
                M.is_busy = 0 // Just in case!