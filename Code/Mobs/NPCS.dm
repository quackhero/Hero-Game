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
        world << "<b>[src.name]</b> uses <b>[S.name]</b> on [target.name]!"
        S.Execute(src, target, E)
    else
        src.EndTurn()