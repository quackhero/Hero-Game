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

            // Reset once-per-battle trigger tracking
            if(M.temp_triggers_used) M.temp_triggers_used.Cut()
            else M.temp_triggers_used = list()

        // --- ATB WAIT INITIALIZATION ---
        // Compute each mob's starting countdown so faster mobs act sooner.
        for(var/mob/M in src.all_participants)
            M.ComputeTotalWeight()
            M.atb_wait = M.CalculateATBWait()

        // --- Step 3: SIG_JOIN_BATTLE — fires after each mob is fully initialized ---
        // Passives with trigger_condition == "SIG_JOIN_BATTLE" and trigger_once=1
        // act as one-shot JoinBattle setup skills (stat buffs, status self-inflicts, etc.)
        for(var/mob/M in src.all_participants)
            M.SendSignal(SIG_JOIN_BATTLE)

        src.Start()

    proc/Start()
        src.is_active = 1
        world << "<b>*** BATTLE START ***</b>"
        // War cries from enemies at encounter start
        for(var/mob/enemy/E in src.enemies)
            if(hascall(E, "Bark")) E.Bark("war_cry")
        src.CombatLoop()


    proc/CombatLoop()
        spawn(0)
            while(src.is_active)
                for(var/mob/M in src.all_participants)
                    if(M.is_dead || M.hp <= M.death_threshold || M.is_busy) continue
                    M.atb_wait--
                    if(M.atb_wait <= 0)
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

    // Returns the correct display name for a newly summoned enemy with the given
    // base_name, based on how many enemies sharing that name already exist.
    // - 0 existing → no suffix ("Wolf")
    // - 1 existing with no suffix → rename it to "Wolf A", return "Wolf B"
    // - N existing with suffixes  → return "Wolf [N+1]" ("Wolf C", "Wolf D", ...)
    // Dead mobs are counted so suffixes are never reused within a battle.
    // Call this before adding the new mob to src.enemies.
    proc/GetSummonName(base_name)
        var/count = 0
        var/mob/nameless = null  // existing mob with exact base_name and no suffix yet
        for(var/mob/E in src.enemies)
            if(E.name == base_name)
                count++
                nameless = E
            else if(findtext(E.name, base_name + " ") == 1)
                count++

        var/new_index = count + 1
        if(new_index == 1)
            return base_name  // only one of this kind — no suffix needed

        // Second arrival: retroactively suffix the previously-alone predecessor
        if(nameless)
            nameless.name = base_name + " " + encounter_factory.Suffix(1)

        return base_name + " " + encounter_factory.Suffix(new_index)

    proc/CheckStatus()
        var/p_alive = 0
        var/e_alive = 0
        for(var/mob/M in src.players) if(!M.is_dead && M.hp > M.death_threshold) p_alive++
        for(var/mob/M in src.enemies) if(!M.is_dead && M.hp > M.death_threshold) e_alive++

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

            // 1b. Give Gil
            var/total_gil = 0
            for(var/mob/enemy/E in src.enemies)
                if("gil_reward" in E.vars)
                    total_gil += E:gil_reward
            if(total_gil > 0)
                for(var/mob/M in src.players)
                    M.gil += total_gil
                    M << "<font color='#FFD700'><b>Received [total_gil] Gil!</b></font>"

            // 2. Roll for Loot
            // drop_key may be a string item ID (JSON NPC) or a type path (legacy hardcoded enemy)
            var/list/dropped_items = list()
            for(var/mob/enemy/E in src.enemies)
                if(!E.loot_table || !E.loot_table.len) continue
                for(var/drop_key in E.loot_table)
                    var/drop_chance = E.loot_table[drop_key]
                    if(prob(drop_chance))
                        if(drop_key in dropped_items)
                            dropped_items[drop_key] += 1
                        else
                            dropped_items[drop_key] = 1

            // 3. Distribute the Loot to Players
            if(dropped_items.len > 0)
                for(var/mob/M in src.players)
                    for(var/drop_key in dropped_items)
                        var/amount = dropped_items[drop_key]

                        // Create the first instance — used for name display AND added to inventory
                        // JSON string ID → factory clone; legacy type path → new()
                        var/datum/item/first
                        if(istext(drop_key))
                            first = item_factory.MakeItem(drop_key)
                        else
                            first = new drop_key()

                        if(!first) continue

                        if(amount > 1)
                            M << "<font color='#00FF00'><b>[M.name] received [first.name] x[amount]</b></font>"
                        else
                            M << "<font color='#00FF00'><b>[M.name] received [first.name] x1</b></font>"

                        M.inventory += first  // Reuse the first item instead of discarding it
                        for(var/i = 2 to amount)
                            var/datum/item/loot
                            if(istext(drop_key))
                                loot = item_factory.MakeItem(drop_key)
                            else
                                loot = new drop_key()
                            if(loot) M.inventory += loot

        if(result == "Defeat")
            // Survivors taunt the fallen party
            for(var/mob/enemy/E in src.enemies)
                if(!E.is_dead && hascall(E, "Bark")) E.Bark("win")

        // --- CONSOLIDATED CLEANUP LOOP ---
        for(var/mob/M in src.all_participants)
            M.atb_gauge = 0
            M.is_busy = 0
            M.current_encounter = null
            // Step 20: clear the mark flag so it doesn't persist between battles
            if("is_marked" in M.vars) M.is_marked = 0
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

        var/party_mult = 1 + ((P - 1) ** 0.75)
        var/exp_player = round((total_enemy_exp * party_mult) / P)

        // Ensure EXP is never negative
        if(exp_player < 1) exp_player = 0

        return exp_player
