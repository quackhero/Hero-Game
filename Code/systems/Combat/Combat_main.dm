/**
 * The Encounter datum manages a single combat instance.
 * This is the core engine for the ATB system and battle flow.
 */
datum/encounter
    var/list/players = list()
    var/list/enemies = list()
    var/list/all_participants = list()

    var/is_active = 0
    var/pause_atb = 0 // Used to freeze ATB during skill timelines/cinematics
    var/tick_rate = 1  // 1 decisecond (0.1s) loop speed

    New(list/P, list/E)
        src.players = P
        src.enemies = E
        src.all_participants = P + E

        // Link participants to this encounter for targeting logic
        for(var/mob/M in src.all_participants)
            M.current_encounter = src

        src.Start()

    /**
     * Starts the battle and kicks off the background loop.
     */
    proc/Start()
        src.is_active = 1
        world << "<b>The battle has begun!</b>"
        src.CombatLoop()

    /**
     * The Heartbeat: Increases ATB gauges for everyone in the fight.
     */
    proc/CombatLoop()
        spawn(0)
            while(src.is_active)
                // If the game isn't paused for a skill message/animation
                if(!src.pause_atb)
                    for(var/mob/M in src.all_participants)
                        // Ignore dead mobs or mobs already taking their turn
                        if(M.hp <= 0 || M.is_busy)
                            continue

                        // ATB increases based on speed/agility
                        M.atb_gauge += (M.spd + 1)

                        if(M.atb_gauge >= 100)
                            M.atb_gauge = 100
                            src.ExecuteTurn(M)

                sleep(src.tick_rate)

    /**
     * Called when a Mob's gauge hits 100.
     */
    proc/ExecuteTurn(mob/M)
        M.is_busy = 1 // Lock the mob so it doesn't get double turns

        // Tells the mob to pick an action (Player menu or AI logic)
        M.ReadyTurn(src)

    /**
     * Returns the opposing team list based on the looker's side.
     */
    proc/GetEnemies(mob/looker)
        if(looker in src.players)
            return src.enemies
        return src.players

    /**
     * Checks if either side has been wiped out.
     */
    proc/CheckStatus()
        var/p_alive = 0
        var/e_alive = 0

        for(var/mob/P in src.players)
            if(P.hp > 0) p_alive++

        for(var/mob/E in src.enemies)
            if(E.hp > 0) e_alive++

        if(e_alive <= 0)
            src.EndBattle("Victory")
        else if(p_alive <= 0)
            src.EndBattle("Defeat")

    /**
     * Cleans up the state when combat finishes.
     */
    proc/EndBattle(result)
        src.is_active = 0
        world << "<b>Battle Result: [result]!</b>"

        for(var/mob/M in src.all_participants)
            M.atb_gauge = 0
            M.is_busy = 0
            M.current_encounter = null

        // The datum will eventually be garbage collected once references are gone.