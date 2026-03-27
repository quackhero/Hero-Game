// ============================================================
// DAMAGE CONTEXT
// Represents a single damage instance as it travels through the
// resolution pipeline. Created by TakeDamage(), resolved by
// ResolveDamage(), and read back by TakeDamage to apply results.
// ============================================================
datum/damage_context
    var/mob/attacker
    var/mob/defender
    var/base_damage  = 0
    var/physical_type  = ""     // "Slashing", "Piercing", "Blunt", "" if none
    var/elemental_type = ""     // "Fire", "Ice", etc. "" if none
    var/is_true_damage = 0      // If 1: bypasses resilience, elemental cycle, and affinities
    var/bypass = 0              // Reduces effective resilience (bypass=-1 ignores it entirely)
    var/final_damage   = 0
    var/was_absorbed   = 0      // If 1, damage should heal the defender instead
    var/was_nulled     = 0      // If 1, damage was completely blocked
    var/hit_weakness   = 0      // If 1, elemental cycle triggered a weakness (show WEAK!)
    var/hit_resist     = 0      // If 1, an affinity blocked some damage (show RESIST)
    var/pre_defend_damage = 0   // Damage value captured just before the defending-halving step

    // Runs the full damage resolution pipeline in order and populates
    // final_damage, was_absorbed, was_nulled, hit_weakness, hit_resist.
    proc/ResolveDamage()
        // Step 1: seed from base
        src.final_damage = src.base_damage

        // Step 2: True damage bypasses everything except the floor
        if(src.is_true_damage)
            src.final_damage = max(1, round(src.final_damage))
            return src

        // Step 3: Resilience reduction
        if(src.defender)
            if(src.bypass == -1)
                // bypass=-1 means ignore resilience entirely (replaces old bypass=-1 pattern)
                pass
            else
                src.final_damage = max(0, src.final_damage - max(0, src.defender.resilience - src.bypass))

        // Step 4: Elemental cycle check via element_factory
        // Uses the defender's "attribute" var as their elemental identity.
        if(src.elemental_type != "" && src.defender)
            var/def_attr = ("attribute" in src.defender.vars) ? src.defender.vars["attribute"] : ""
            if(def_attr != "")
                var/mult = element_factory.GetMultiplier(src.elemental_type, def_attr)
                if(mult != 1.0)
                    src.final_damage = round(src.final_damage * mult)
                    if(mult > 1.0)
                        src.hit_weakness = 1
                        // Modular weakness bonus from passives
                        if(src.attacker)
                            for(var/datum/skill/P in src.attacker.equipped_skills)
                                if(P.is_passive && P.passive_weakness_bonus_pct != 0)
                                    src.final_damage = round(src.final_damage * (1.0 + P.passive_weakness_bonus_pct))

        // Step 5: Affinity resolution
        // Each datum/component/affinity on the defender gets to modify final_damage.
        // Diminishing returns are automatic: each component multiplies remaining damage.
        // Processing stops early if the hit was fully nulled or absorbed.
        if(src.defender)
            for(var/datum/component/affinity/A in src.defender.components)
                if(src.was_nulled || src.was_absorbed) break
                A.Apply(src)

        // Step 6: Defending halves damage (Shield Wall upgrades to 75% reduction)
        if(src.defender && src.defender.defending)
            src.pre_defend_damage = round(src.final_damage)
            var/defend_mult = 0.5
            if(hascall(src.defender, "HasStatus") && src.defender.HasStatus("shield_wall"))
                defend_mult = 0.25
            src.final_damage = round(src.final_damage * defend_mult)

        // Step 7: Floor (skip if the hit was suppressed)
        if(!src.was_nulled && !src.was_absorbed)
            src.final_damage = max(1, round(src.final_damage))

        return src
