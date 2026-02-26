datum/skill/heavy_strike
    name = "Heavy Strike"
    cost = 10

    New()
        var/datum/skill_event/damage/D = new()
        D.txt = "(I) delivers a crushing blow to (enemy)!"
        D.formula = "STR * 1.5"
        src.event_timeline += D
