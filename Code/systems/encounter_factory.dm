// ============================================================
// ENCOUNTER FACTORY
// Stores pre-defined encounter templates (name, type, enemies).
// Loaded from / saved to Encounters.json.
// Used by the Manage_Encounters admin verb.
// ============================================================

datum/encounter_factory
    var/list/loaded_encounters = list()  // list of assoc lists: name, type, enemies

    proc/LoadAllEncounters()
        if(!fexists("Encounters.json"))
            text2file("[]", "Encounters.json")
            return
        var/raw = file2text("Encounters.json")
        var/list/data = json_decode(raw)
        if(islist(data))
            src.loaded_encounters = data
        if(src.loaded_encounters.len)
            world << "<b>[src.loaded_encounters.len] Encounter(s) loaded.</b>"

    proc/SaveAllEncounters()
        text2file(json_encode(src.loaded_encounters), "Encounters.json")

    // Appends an encounter assoc-list as a single element.
    // Direct index assignment avoids any list.Add() flattening ambiguity.
    proc/AddEncounter(list/enc)
        src.loaded_encounters.len++
        src.loaded_encounters[src.loaded_encounters.len] = enc

    // Excel-style column suffix: 1=A, 2=B, ..., 26=Z, 27=AA, 28=AB, ...
    // Supports any number of duplicates without running out of labels.
    proc/Suffix(n)
        var/result = ""
        while(n > 0)
            var/rem = (n - 1) % 26
            result = ascii2text(65 + rem) + result
            n = (n - 1 - rem) / 26
        return result