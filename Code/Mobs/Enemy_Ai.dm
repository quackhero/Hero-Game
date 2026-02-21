mob/enemy/TakeAction(datum/encounter/E)
    if(src.is_dead) return
    
    if(prob(80) || !src.skills.len)
        var/mob/target = pick(E.players)
        if(target) src.BasicAttack(target)
    else
        var/datum/skill/S = pick(src.skills)
        
        // --- AI AOE LOGIC ---
        if(S.targeting_flags & TARGET_AOE)
            // NPCs target the entire opposing party list
            src << "The [src.name] unleashes [S.name] on everyone!"
            S.Execute(src, E.players, E)
        else
            var/mob/target = pick(E.players)
            if(S && target)
                src << "The [src.name] uses [S.name] on [target.name]!"
                S.Execute(src, target, E)