/*
	These are simple defaults for your project.
 */

world
	fps = 25		// 25 frames per second
	icon_size = 32	// 32x32 icon size by default

	view = 6		// show up to 6 tiles outward from center (13x13 view)
	New()
		..()
		skill_factory.LoadAllSkills()
		status_factory.LoadAllStatuses()
		item_factory.LoadAllItems()
		npc_factory.LoadAllNPCs()        // Must be last — references skills and items
// Make objects move 8 pixels per tick when walking

mob
	step_size = 8

obj
	step_size = 8
