datum/skill_event/logic
    var/logic_type = "Set"
    var/var_name = ""
    var/val_ref = "0"
    var/compare_op = "=="
    var/target_ref = 0 

    // ERROR FIX: Removed "proc/" because this is an override
    Run(mob/user, mob/target, datum/skill/S, datum/encounter/E)
        
        var/mob/M = user
        if(target_ref == 1) M = target
        
        if(!M) return 
        
        // ERROR FIX: Check if global.parser exists
        var/final_val = 0
        if(global.parser)
            final_val = global.parser.Evaluate(val_ref, user, target)
        
        // ERROR FIX: "hasvar" is not valid. Use "in M.vars"
        if(!(var_name in M.vars)) 
            return

        switch(logic_type)
            if("Set") M.vars[var_name] = final_val
            if("Add") M.vars[var_name] += final_val
            if("Sub") M.vars[var_name] -= final_val
                
            if("ListAdd")
                if(islist(M.vars[var_name]))
                    M.vars[var_name] += final_val
                    
            if("ListRemove")
                if(islist(M.vars[var_name]))
                    M.vars[var_name] -= final_val

            if("Check")
                var/current_val = M.vars[var_name]
                var/passed = 0
                
                switch(compare_op)
                    if("==") if(current_val == final_val) passed = 1
                    if("!=") if(current_val != final_val) passed = 1
                    if(">")  if(current_val > final_val)  passed = 1
                    if("<")  if(current_val < final_val)  passed = 1
                    if(">=") if(current_val >= final_val) passed = 1
                    if("<=") if(current_val <= final_val) passed = 1
                
                // ERROR FIX: Ensure S has MsgList before accessing
                if(S && ("MsgList" in S.vars))
                    // We have to cast to list to avoid "undefined operator" errors if strict
                    var/list/L = S.vars["MsgList"] 
                    if(passed)
                        if(L.len >= 1) S.ExecuteStep(user, target, L[1])
                    else
                        if(L.len >= 2) S.ExecuteStep(user, target, L[2])