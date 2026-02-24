var/list/chat_log = list()

proc/AddLog(msg)
    chat_log += msg
    if(chat_log.len > 20)
        chat_log.Cut(1, 2)

mob
    Logout()
        src.SavePlayer()
        // We purposely do NOT delete the mob here.
        // This leaves their body in the world (and the battle) when they disconnect!
        ..()

    Login()
        ..()
        world << "<span style='color: #0000FF'>[src.name] has plugged in!</span>"

        if(chat_log.len > 0)
            src << "<span style='color: #555555'>--- Last 20 Messages ---</span>"
            for(var/line in chat_log)
                src << line
            src << "<span style='color: #555555'>-----------------------</span>"
        if(!src.current_encounter)
            src.is_busy = 0

        // --- THE LOAD / CREATE FORK ---
        if(src.LoadPlayer())
            src << "<font color='#00FF00'><b>Save file loaded successfully! Welcome back, [src.name].</b></font>"
        else
            spawn(5)
                src.CharacterCreation()

mob
    verb
        say(msg as text)
            set category = "Communication"
            set name = "Say"
            if(!msg) return
            // Format: Name :: Message
            var/full_msg = "<b>[src.name] ::</b> [msg]"
            AddLog(full_msg)
            world << full_msg
        ooc(msg as text)
            set category = "Communication"
            set name = "OOC"
            if(!msg) return
            // Format: (OOC) Name :: Message
            world << "<font color='#4B0082'>(OOC) [src.name] :: [msg]</font>"
        emote(msg as text)
            set category = "Communication"
            set name = "Emote"
            if(!msg) return
            // Format: Italics and Green
            var/full_msg = "<span style='color: #008000'><i>[src.name] [msg]</i></span>"
            AddLog(full_msg)
            world << full_msg