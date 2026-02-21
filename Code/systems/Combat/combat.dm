/**
 * The Encounter datum manages the lifecycle of a single battle.
 * It tracks participants, turn order, and the global combat state.
 */
datum/encounter
    var/list/players = list()
    var/list/enemies = list()
    var/list/all_participants = list()
    
    var/is_active = 0
    var/pause_atb = 0 // Set to 1 when a skill timeline is running
    
    var/tick_rate = 1 // 1 decisecond (0.1s) loop speed

    New(list/P, list/E)
        src.players = P
        src.enemies = E
        src.all_participants = P + E
        
        // Link all participants to this encounter
        for(mob/M in src.all_participants)
            M.current_encounter = src
            
        src.Start()

    /**
     * Entry point for the battle.
     */
    proc/Start()
        src.is_active = 1
        world << "<b>The battle begins!</b>"
        src.CombatLoop()

    /**
     * The Heartbeat: Continuously increases ATB gauges unless paused.
     */
    proc/CombatLoop()
        spawn(0)
            while(src.is_active)
                if(!src.pause_atb)
                    for(mob/M in src.all_participants)
                        // Skip if dead or already acting
                        if(M.hp <= 0 || M.is_busy) 
                            continue
                        
                        // ATB increases based on Agility/Speed
                        M.atb_gauge += (M.speed + 1)
                        
                        if(M.atb_gauge >= 100)
                            M.atb_gauge = 100
                            src.ExecuteTurn(M)
                
                sleep(src.tick_rate)

    /**
     * Triggered when a Mob's gauge hits 100.
     */
    proc/ExecuteTurn(mob/M)
        M.is_busy = 1 // Prevent ATB from moving for this mob
        
        // In Player_Logic.dm or Enemy_AI.dm, this opens menus or picks targets
        M.ReadyTurn(src)

    /**
     * Utility to return the opposing team. 
     * Essential for AOE and target selection.
     */
    proc/GetEnemies(mob/looker)
        if(looker in src.players) 
            return src.enemies
        return src.players

    /**
     * Called whenever a mob dies.
     */
    proc/CheckStatus()
        var/p_alive = 0
        var/e_alive = 0
        
        for(mob/M in src.players) if(M.hp > 0) p_alive++
        for(mob/M in src.enemies) if(M.hp > 0) e_alive++
        
        if(e_alive <= 0) 
            src.EndBattle("Victory")
        else if(p_alive <= 0) 
            src.EndBattle("Defeat")

    proc/EndBattle(result)
        src.is_active = 0
        world << "<b>Combat Result: [result]</b>"
        
        // Cleanup participants
        for(mob/M in src.all_participants)
            M.atb_gauge = 0
            M.is_busy = 0
            M.current_encounter = null