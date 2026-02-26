var/datum/status_factory/status_factory = new()

datum/status_factory
    var/list/loaded_statuses = list()

    proc/LoadAllStatuses()
        if(!fexists("Statuses.json"))
            world.log << "ERROR: Statuses.json not found!"
            return

        var/raw_text = file2text("Statuses.json")
        var/list/json_data = json_decode(raw_text)

        for(var/list/status_data in json_data)
            var/datum/component/status/S = new()
            S.id = status_data["id"]
            S.name = status_data["name"]
            
            // Trigger / Counter logic
            if("trigger_condition" in status_data) S.trigger_condition = status_data["trigger_condition"]
            if("trigger_chance" in status_data) S.trigger_chance = status_data["trigger_chance"]
            if("reaction_skill_id" in status_data) S.reaction_skill_id = status_data["reaction_skill_id"]
            if("trigger_category" in status_data) S.trigger_category = status_data["trigger_category"]

            // NEW: DoT and HoT logic
            if("dot_amount" in status_data) S.dot_amount = status_data["dot_amount"]
            if("dot_type" in status_data) S.dot_type = status_data["dot_type"]
            if("hot_amount" in status_data) S.hot_amount = status_data["hot_amount"]

            if("stat_mod" in status_data) S.stat_mod = status_data["stat_mod"]
            if("stat_amount" in status_data) S.stat_amount = status_data["stat_amount"]

            src.loaded_statuses[S.id] = S
            
        world << "<b>[src.loaded_statuses.len] JSON Statuses Loaded!</b>"