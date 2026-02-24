mob/enemy/TakeAction(datum/encounter/E)
    if(src.is_dead) return
    
    // 1. Filter out dead players so the AI doesn't target "ghosts"
    var/list/living_players = list()
    for(var/mob/P in E.players)
        if(P.hp > 0) living_players += P
        
    if(!living_players.len) return // No one left to hit!

    // 2. Decide between Skill or Basic Attack
    var/can_use_skill = 0
    var/datum/skill/S 
    
    if(src.skills.len)
        S = pick(src.skills)
        // Check if the enemy actually has the MP to use this skill
        if(src.mp >= S.cost)
            can_use_skill = 1

    // If prob(80) rolls true, OR they have no skills, OR they can't afford the skill...
    if(prob(80) || !can_use_skill)
        var/mob/target = pick(living_players)
        if(target) src.BasicAttack(target)
    
    else
        // --- AI AOE LOGIC ---
        if(S.targeting_flags & TARGET_AOE)
            world << "<b>The [src.name] unleashes [S.name] on everyone!</b>"
            S.Execute(src, living_players, E)
        else
            var/mob/target = pick(living_players)
            if(S && target)
              //  world << "<b>The [src.name] uses [S.name] on [target.name]!</b>"
                S.Execute(src, target, E)
    
    // 3. Ensure the gauge is reset after the action is finished!
    src.atb_gauge = 0