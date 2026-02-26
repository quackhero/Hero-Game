// ============================================================
// UNIVERSAL AI
// Any mob can call src.UniversalAI(E) from their TakeAction().
// Decision priority (highest to lowest):
//   1. Emergency item use  (HP < 30% → hp_restore, MP empty → mp_restore)
//   2. Defend              (5% flat chance)
//   3. Skill               (35% if usable skills exist)
//   4. Basic attack        (fallback / most common)
// ============================================================

mob/proc/UniversalAI(datum/encounter/E)
    if(src.is_dead || !E) return

    // --- 1. Gather battlefield state ---
    var/list/living_enemies = list()
    var/list/living_allies  = list()

    for(var/mob/M in E.GetEnemies(src))
        if(!M.is_dead && M.hp > M.death_threshold)
            living_enemies += M

    for(var/mob/M in E.GetAllies(src))
        if(!M.is_dead && M.hp > M.death_threshold)
            living_allies += M

    if(!living_enemies.len)
        src.EndTurn()
        return

    var/hp_pct = (src.hp / max(1, src.max_hp)) * 100

    // --- 2. Emergency item use ---
    if(src.equipped_items.len)

        // HP critically low — try to use a healing item on self
        if(hp_pct < 30)
            for(var/datum/item/consumable/I in src.equipped_items)
                if(I.ai_category == "hp_restore")
                    world << "<i>[src.name] reaches for a [I.name]!</i>"
                    if(I.Use(src, src, E))
                        src.equipped_items -= I
                    src.EndTurn()
                    return

        // MP empty but has skills — try to restore MP
        if(src.mp == 0 && src.skills.len)
            for(var/datum/item/consumable/I in src.equipped_items)
                if(I.ai_category == "mp_restore")
                    world << "<i>[src.name] reaches for a [I.name]!</i>"
                    if(I.Use(src, src, E))
                        src.equipped_items -= I
                    src.EndTurn()
                    return

    // --- 3. Build usable active skill list ---
    // Filters out passives and skills the mob cannot currently afford.
    var/list/usable_skills = list()
    for(var/datum/skill/S in src.skills)
        if(S.is_passive) continue
        if(src.mp < S.cost) continue
        if(S.hp_cost > 0 && src.hp <= S.hp_cost) continue
        if(S.ammo_type && !src.HasAmmo(S.ammo_type, S.ammo_cost)) continue
        usable_skills += S

    // --- 4. Roll for action type ---
    var/roll = rand(1, 100)

    if(roll <= 5)
        // Defend (rare)
        src.defending = 1
        world << "<i>[src.name] braces for impact!</i>"
        src.EndTurn()
        return

    if(roll <= 40 && usable_skills.len)
        // Attempt to use a skill; falls through to basic attack if no valid target found
        var/datum/skill/S = pick(usable_skills)
        if(src.AIUseSkill(S, living_enemies, living_allies, E))
            return
        // Skill found no valid target — fall through to basic attack

    // Basic attack (most common outcome)
    var/mob/target = pick(living_enemies)
    src.BasicAttack(target)


// ============================================================
// SKILL EXECUTION HELPER
// Handles target selection based on the skill's targeting flags.
// Returns 1 if the skill was executed, 0 if no valid target was found.
// ============================================================

mob/proc/AIUseSkill(datum/skill/S, list/living_enemies, list/living_allies, datum/encounter/E)

    // Self-targeting skills (buffs, self-heals, etc.)
    if(S.targeting_flags & TARGET_SELF)
        S.Execute(src, src, E)
        return 1

    // AOE skills — pick the right side automatically
    if(S.targeting_flags & TARGET_AOE)
        if(S.targeting_flags & (TARGET_HEAL | TARGET_REVIVE))
            var/list/aoe_targets = src.AIBuildReviveList(living_allies, E, S)
            if(aoe_targets.len)
                S.Execute(src, aoe_targets, E)
                return 1
        else
            if(living_enemies.len)
                S.Execute(src, living_enemies, E)
                return 1
        return 0

    // Healing / Revive — single target, pick the most wounded valid ally
    if(S.targeting_flags & (TARGET_HEAL | TARGET_REVIVE))
        var/mob/best = null
        var/lowest_hp = 999999

        var/list/candidates = living_allies.Copy()
        if(S.targeting_flags & TARGET_REVIVE)
            // Also consider dead allies as revive targets
            for(var/mob/M in E.GetAllies(src))
                if(M.is_dead && !(M in candidates))
                    candidates += M

        for(var/mob/M in candidates)
            if(S.IsValidTarget(src, M) && M.hp < lowest_hp)
                lowest_hp = M.hp
                best = M

        if(best)
            S.Execute(src, best, E)
            return 1
        return 0

    // Default: single-target offensive — pick a random living enemy
    if(!living_enemies.len) return 0
    var/mob/target = pick(living_enemies)
    if(S.IsValidTarget(src, target))
        S.Execute(src, target, E)
        return 1

    // Last resort: scan all enemies for any valid target
    for(var/mob/M in living_enemies)
        if(S.IsValidTarget(src, M))
            S.Execute(src, M, E)
            return 1

    return 0 // No valid target could be found


// ============================================================
// HELPER: Build a list of valid revive/heal targets
// Used for AOE healing skills so we don't hand the skill
// a list that contains invalid targets.
// ============================================================

mob/proc/AIBuildReviveList(list/living_allies, datum/encounter/E, datum/skill/S)
    var/list/result = list()
    var/list/candidates = living_allies.Copy()
    if(S.targeting_flags & TARGET_REVIVE)
        for(var/mob/M in E.GetAllies(src))
            if(M.is_dead && !(M in candidates))
                candidates += M
    for(var/mob/M in candidates)
        if(S.IsValidTarget(src, M))
            result += M
    return result


// ============================================================
// ENEMY TakeAction — calls the universal AI
// ============================================================

mob/enemy/TakeAction(datum/encounter/E)
    sleep(5) // Brief pause so the log doesn't blur together
    src.UniversalAI(E)
