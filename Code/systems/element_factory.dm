// ============================================================
// ELEMENT FACTORY
// Loads Elements.json on world start. Provides GetMultiplier()
// for the elemental cycle check inside DamageContext.ResolveDamage()
// and GetColor() for battle log message formatting.
// ============================================================
datum/element_factory
    var/list/loaded_elements = list()

    // Load all element definitions from Elements.json.
    proc/LoadAllElements()
        if(!fexists("Elements.json"))
            world.log << "ERROR: Elements.json not found!"
            return

        var/raw_text = file2text("Elements.json")
        var/list/json_data = json_decode(raw_text)

        for(var/list/elem_data in json_data)
            src.loaded_elements[elem_data["id"]] = elem_data

        world << "<b>[src.loaded_elements.len] Elements Loaded!</b>"

    // Returns 1.2 if attack_element is in target_element's weak_against list.
    // Returns 1.0 otherwise (no interaction or unknown element).
    proc/GetMultiplier(attack_element, target_element)
        if(!attack_element || !target_element) return 1.0
        var/list/elem_data = src.loaded_elements[target_element]
        if(!elem_data) return 1.0
        var/list/weak_list = elem_data["weak_against"]
        if(weak_list && (attack_element in weak_list))
            return 1.2
        return 1.0

    // Returns the hex color string for an element for battle log coloring.
    // Returns white (#FFFFFF) for unknown or empty element IDs.
    proc/GetColor(element_id)
        if(!element_id) return "#FFFFFF"
        var/list/elem_data = src.loaded_elements[element_id]
        if(!elem_data) return "#FFFFFF"
        return elem_data["color"]
