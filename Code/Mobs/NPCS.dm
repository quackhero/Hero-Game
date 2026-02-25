// 1. Officially declare the 'enemy' subtype
mob/enemy
    var/base_exp = 50 // Every enemy will now have this by default!
    var/list/loot_table = list()
    
    // (It automatically inherits level, hp, mp, etc. from the base 'mob')

// 2. Define your specific monsters!
mob/enemy/training_dummy
    name = "Training Dummy"
    level = 1
    base_exp = 50
    
    // Override the base stats just for the dummy
    max_hp = 10
    hp = 10
    strength = 0    // (Was atk)
    resilience = 5  // (Was def)
    dexterity = 15  // (Was spd)
    loot_table = list(/datum/item/potion = 100, /datum/item/ether = 30)
    
    New()
        ..() // Call the parent New()
        // Give the dummy some skills if you want it to fight back!
        src.skills += new /datum/skill/heavy_strike()


mob/enemy/TakeAction(datum/encounter/E)
    // Now that skills is a list, .len will work perfectly
    if(!src.skills || !src.skills.len) 
        src.EndTurn()
        return

    // Pick a random skill from the list we just defined
    var/datum/skill/S = pick(src.skills)
    
    // Pick a random player from the encounter's player list
    var/mob/target = pick(E.players)
    
    if(target)
     //   world << "<b>[src.name]</b> uses <b>[S.name]</b> on [target.name]!"
        S.Execute(src, target, E)
    else
        src.EndTurn()
    
mob/enemy/active_dummy
    name = "Striking Dummy"
    hp = 500
    max_hp = 500
    strength = 1 
    resilience = 5
    dexterity = 10
    
    // The bulletproof AI loop
    TakeAction()
        sleep(10) // Wait 1 second so the combat log doesn't blur together
        
        var/datum/encounter/E = src.current_encounter
        if(!E) return src.EndTurn()
            
        var/list/enemies = E.GetEnemies(src)
        if(!enemies || !enemies.len) return src.EndTurn()
            
        var/mob/target = pick(enemies)
        var/datum/skill/attack_skill = skill_factory.loaded_skills["basic_attack"]
        
        if(attack_skill)
            attack_skill.Execute(src, target, E) 
            src.EndTurn() // Safely end the turn after punching
        else
            src.EndTurn()