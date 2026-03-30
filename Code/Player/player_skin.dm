mob/proc/UpdateSkin()
    if(!src.client) return

    // --- Character Sheet (asheet2) ---

    // Name and Level
    winset(src, "asheet2.s_name", "text=\"  [src.name]\"")
    var/class_name = src.Primary_class ? src.Primary_class.name : "Unknown"
    winset(src, "asheet2.s_level", "text=\" Lv.[src.level] [class_name]\"")

    // HP / MP
    winset(src, "asheet2.s_hp", "text=\"HP: [src.hp]/[src.max_hp]\"")
    winset(src, "asheet2.s_sk", "text=\"MP: [src.mp]/[src.max_mp]\"")

    // Compact stat row
    winset(src, "asheet2.s_atk", "text=\"STR: [src.strength]\"")
    winset(src, "asheet2.s_def", "text=\"RES: [src.resilience]\"")
    winset(src, "asheet2.s_spd", "text=\"DEX: [src.dexterity]\"")
    winset(src, "asheet2.s_ap",  "text=\"INT: [src.intelligence]\"")

    // Detailed stat column (base + equipment bonus)
    var/str_bonus = src.strength    - src.base_strength
    var/dex_bonus = src.dexterity   - src.base_dexterity
    var/int_bonus = src.intelligence - src.base_intelligence
    var/mnd_bonus = src.mind        - src.base_mind
    var/vit_bonus = src.vitality    - src.base_vitality
    var/res_bonus = src.resilience  - src.base_resilience

    winset(src, "asheet2.s_cha", "text=\" STR: [src.base_strength]+[str_bonus]\"")
    winset(src, "asheet2.s_int", "text=\" DEX: [src.base_dexterity]+[dex_bonus]\"")
    winset(src, "asheet2.s_str", "text=\" INT: [src.base_intelligence]+[int_bonus]\"")
    winset(src, "asheet2.s_end", "text=\" MND: [src.base_mind]+[mnd_bonus]\"")
    winset(src, "asheet2.s_agi", "text=\" VIT: [src.base_vitality]+[vit_bonus]\"")
    winset(src, "asheet2.s_sty", "text=\" RES: [src.base_resilience]+[res_bonus]\"")

    // EXP and Gil
    winset(src, "asheet2.s_exp", "text=\" EXP: [src.current_exp]/[src.max_exp]\"")
    winset(src, "asheet2.s_gil", "text=\" Gil: [src.gil]\"")

    // Equipment slot labels
    var/wpn_name = src.equipped_weapon    ? src.equipped_weapon.name    : "None"
    var/arm_name = src.equipped_armor     ? src.equipped_armor.name     : "None"
    var/acc_name = src.equipped_accessory ? src.equipped_accessory.name : "None"
    winset(src, "asheet2.s_wpn1", "text=\"[wpn_name]\"")
    winset(src, "asheet2.s_arm",  "text=\"[arm_name]\"")
    winset(src, "asheet2.s_acc1", "text=\"[acc_name]\"")

    // --- Bars (0-100 scale) ---
    var/hp_pct = src.max_hp  > 0 ? round((src.hp           / src.max_hp)  * 100) : 0
    var/mp_pct = src.max_mp  > 0 ? round((src.mp           / src.max_mp)  * 100) : 0
    var/xp_pct = src.max_exp > 0 ? round((src.current_exp  / src.max_exp) * 100) : 0

    // asheet2 bars
    winset(src, "asheet2.s_hpbar",  "value=[hp_pct]")
    winset(src, "asheet2.s_skbar",  "value=[mp_pct]")
    winset(src, "asheet2.s_expbar", "value=[xp_pct]")

    // Main HUD bars (default window)
    winset(src, "default.barhp",  "value=[hp_pct]")
    winset(src, "default.barsk",  "value=[mp_pct]")
    winset(src, "default.barxp",  "value=[xp_pct]")

    // Main HUD name
    winset(src, "default.name", "text=\"[src.name]\"")

    // Ensure core HUD elements are visible
    winset(src, "default.barhp",    "is-visible=true")
    winset(src, "default.barsk",    "is-visible=true")
    winset(src, "default.labelhp",  "is-visible=true")
    winset(src, "default.labelsk",  "is-visible=true;text=\"MP\"")
