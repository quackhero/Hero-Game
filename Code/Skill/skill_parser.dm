// ============================================================
// 1. GLOBAL DEFINITION
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

        // --- STEP 0: Resolve status checks (USER_HAS_STATUS before HAS_STATUS — it's a substring) ---
        while(findtext(processed, "USER_HAS_STATUS("))
            var/start = findtext(processed, "USER_HAS_STATUS(")
            var/paren_close = findtext(processed, ")", start + 15)
            if(!paren_close) break
            var/status_id = copytext(processed, start + 16, paren_close)
            var/result = (user && hascall(user, "HasStatus") && user.HasStatus(status_id)) ? "1" : "0"
            processed = copytext(processed, 1, start) + result + copytext(processed, paren_close + 1)

        while(findtext(processed, "HAS_STATUS("))
            var/start = findtext(processed, "HAS_STATUS(")
            var/paren_close = findtext(processed, ")", start + 10)
            if(!paren_close) break
            var/status_id = copytext(processed, start + 11, paren_close)
            var/result = (target && hascall(target, "HasStatus") && target.HasStatus(status_id)) ? "1" : "0"
            processed = copytext(processed, 1, start) + result + copytext(processed, paren_close + 1)

        // --- STEP A: Replace Target Stats (before user stats to avoid partial matches) ---
        if(target)
            processed = replacetext(processed, "STR(E)", "[target.strength]")
            processed = replacetext(processed, "RES(E)", "[target.resilience]")
            processed = replacetext(processed, "DEX(E)", "[target.dexterity]")
            processed = replacetext(processed, "INT(E)", "[target.intelligence]")
            processed = replacetext(processed, "MND(E)", "[target.mind]")
            processed = replacetext(processed, "VIT(E)", "[target.vitality]")
            processed = replacetext(processed, "HP(E)",  "[target.hp]")
            processed = replacetext(processed, "MP(E)",  "[target.mp]")

        // --- STEP B: Replace User Stats ---
        if(user)
            processed = replacetext(processed, "STR", "[user.strength]")
            processed = replacetext(processed, "RES", "[user.resilience]")
            processed = replacetext(processed, "DEX", "[user.dexterity]")
            processed = replacetext(processed, "INT", "[user.intelligence]")
            processed = replacetext(processed, "MND", "[user.mind]")
            processed = replacetext(processed, "VIT", "[user.vitality]")
            processed = replacetext(processed, "HP",  "[user.hp]")
            processed = replacetext(processed, "MP",  "[user.mp]")

        // --- STEP C: Handle comparison operators (multi-char ops checked before single-char) ---
        if(findtext(processed, "<="))
            var/list/parts = splittext(processed, "<=")
            return CalculateMath(parts[1]) <= CalculateMath(parts[2]) ? 1 : 0
        if(findtext(processed, ">="))
            var/list/parts = splittext(processed, ">=")
            return CalculateMath(parts[1]) >= CalculateMath(parts[2]) ? 1 : 0
        if(findtext(processed, "=="))
            var/list/parts = splittext(processed, "==")
            return CalculateMath(parts[1]) == CalculateMath(parts[2]) ? 1 : 0
        if(findtext(processed, "!="))
            var/list/parts = splittext(processed, "!=")
            return CalculateMath(parts[1]) != CalculateMath(parts[2]) ? 1 : 0
        if(findtext(processed, "<"))
            var/list/parts = splittext(processed, "<")
            return CalculateMath(parts[1]) < CalculateMath(parts[2]) ? 1 : 0
        if(findtext(processed, ">"))
            var/list/parts = splittext(processed, ">")
            return CalculateMath(parts[1]) > CalculateMath(parts[2]) ? 1 : 0

        // --- STEP D: Calculate the Result ---
        return CalculateMath(processed)

    // A simple parser that handles + - * / 
    proc/CalculateMath(t)
        // 0. Guard: empty token (e.g. leading "-" splits into ["", "5"]) → 0
        if(!t || t == "") return 0

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
                if(val == 0)
                    world.log << "WARNING: Division by zero in skill formula: [t]"
                    return 0
                total /= val
            return total

        // 6. Final fallback: Convert what's left to a number
        return text2num(t)