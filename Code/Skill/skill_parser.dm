// ============================================================
// 1. GLOBAL DEFINITION (Fixes "undefined var" error)
// ============================================================
var/datum/skill_parser/parser = new()

// ============================================================
// 2. THE PARSER LOGIC
// ============================================================
datum/skill_parser
    
    proc/Evaluate(formula, mob/user, mob/target)
        if(!formula || formula == "0") return 0
        
        // If it's already a simple number, just return it
        if(isnum(formula)) return formula
        if(isnum(text2num(formula))) return text2num(formula)

        var/processed = formula
        
        // --- STEP A: Replace User Stats ---
        // (Make sure 'ap', 'atk', etc. exist in Base.dm!)
        if(user)
            processed = replacetext(processed, "ATK", "[user.atk]")
            processed = replacetext(processed, "DEF", "[user.def]")
            processed = replacetext(processed, "SPD", "[user.spd]")
            processed = replacetext(processed, "SK",  "[user.sk]")
            processed = replacetext(processed, "HP",  "[user.hp]")
            processed = replacetext(processed, "MP",  "[user.mp]")
            // Only use AP if you added var/ap to Base.dm
            if("ap" in user.vars) processed = replacetext(processed, "AP", "[user.ap]")

        // --- STEP B: Replace Target Stats ---
        if(target)
            processed = replacetext(processed, "ATK(E)", "[target.atk]")
            processed = replacetext(processed, "DEF(E)", "[target.def]")
            processed = replacetext(processed, "SPD(E)", "[target.spd]")
            processed = replacetext(processed, "SK(E)",  "[target.sk]")
            processed = replacetext(processed, "HP(E)",  "[target.hp]")
            processed = replacetext(processed, "MP(E)",  "[target.mp]")

        // --- STEP C: Calculate the Result ---
        return CalculateMath(processed)

    // A simple parser that handles + - * / 
    // Example input: "10 * 5 + 2"
    proc/CalculateMath(t)
        // 1. Remove spaces for easier parsing
        t = replacetext(t, " ", "")
        
        // 2. Handle Addition (Split by +)
        var/list/adds = splittext(t, "+")
        if(adds.len > 1)
            var/total = 0
            for(var/x in adds) total += CalculateMath(x) // Recursion
            return total

        // 3. Handle Subtraction (Split by -)
        var/list/subs = splittext(t, "-")
        if(subs.len > 1)
            var/total = CalculateMath(subs[1])
            for(var/i=2, i<=subs.len, i++) total -= CalculateMath(subs[i])
            return total

        // 4. Handle Multiplication (Split by *)
        var/list/mults = splittext(t, "*")
        if(mults.len > 1)
            var/total = 1
            for(var/x in mults) total *= CalculateMath(x)
            return total

        // 5. Handle Division (Split by /)
        var/list/divs = splittext(t, "/")
        if(divs.len > 1)
            var/total = CalculateMath(divs[1])
            for(var/i=2, i<=divs.len, i++)
                var/val = CalculateMath(divs[i])
                if(val != 0) total /= val
            return total

        // 6. Final fallback: Convert what's left to a number
        return text2num(t)