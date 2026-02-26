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
        
        // --- THE CLEAN SLATE INITIALIZATION ---
        for(var/mob/M in src.all_participants)
            M.current_encounter = src
            M.atb_gauge = 0 
            M.is_busy = 0 // Guarantees nobody enters combat locked out!

            if(M.hp < 1)
                M.hp = 1
            if(M.is_dead)
                M.is_dead = 0
            
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

                    M.atb_gauge += (M.dexterity + 1)
                    
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
        
        if(result == "Victory")
            // 1. Give EXP
            var/exp_reward = CalculateRewardEXP(src.players, src.enemies)
            for(var/mob/M in src.players)
                M.GainEXP(exp_reward)
                
            // 2. Roll for Loot
            var/list/dropped_items = list() 
            for(var/mob/enemy/E in src.enemies)
                if(E.loot_table)
                    for(var/item_path in E.loot_table)
                        var/drop_chance = E.loot_table[item_path]
                        
                        // prob() is BYOND's built-in percentage dice roll!
                        if(prob(drop_chance)) 
                            // If it dropped, add it to the count!
                            if(item_path in dropped_items)
                                dropped_items[item_path] += 1
                            else
                                dropped_items[item_path] = 1

            // 3. Distribute the Loot to Players
            if(dropped_items.len > 0)
                for(var/mob/M in src.players)
                    for(var/item_path in dropped_items)
                        var/amount = dropped_items[item_path]
                        
                        // Spawn a temporary item just to read its proper name
                        var/datum/item/temp = new item_path()
                        var/i_name = temp.name
                        
                        // Print the grouped message! 
                        if(amount > 1)
                            M << "<font color='#00FF00'><b>[M.name] has received [i_name]s x[amount]</b></font>"
                        else
                            M << "<font color='#00FF00'><b>[M.name] has received [i_name] x1</b></font>"
                            
                        // Actually put the datums in the player's inventory
                        for(var/i = 1 to amount)
                            M.inventory += new item_path()
                            
        // --- CONSOLIDATED CLEANUP LOOP ---
        for(var/mob/M in src.all_participants)
            M.atb_gauge = 0
            M.is_busy = 0
            M.current_encounter = null
            if(M.client) 
                M << browse(null, "window=battle_menu")

    proc/CalculateRewardEXP(list/mob/party, list/mob/enemies)
        if(!party || !party.len || !enemies || !enemies.len) return 0
        var/P = party.len
        
        var/total_party_level = 0
        for(var/mob/M in party) total_party_level += M.level
        var/L_p = round(total_party_level / P)

        var/total_enemy_exp = 0
        var/f_Lp_suppression_penalty = 0 // Change this later if you want a custom penalty

        for(var/mob/enemy/E in enemies)
            var/L_e = E.level
            var/B = E.base_exp 
            var/exp_from_enemy = 0

            // The Anti-Grind Check
            if(L_p > (L_e + 15)) 
                exp_from_enemy = B * 0.002
            else 
                exp_from_enemy = max(B + (L_e - L_p) - f_Lp_suppression_penalty, 0)
                
            total_enemy_exp += exp_from_enemy

        var/M = 1 + ((P - 1) ** 0.75)
        var/exp_player = round((total_enemy_exp * M) / P)
        
        // Ensure EXP is never negative
        if(exp_player < 1) exp_player = 0

        return exp_player