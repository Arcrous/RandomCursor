#Requires AutoHotkey v2.0

/**
 * This function will check if hotkeys are working properly
 * Call it from your main script to verify hotkey registration
 */
VerifyHotkeys() {
    global app

    if !IsSet(app) || !app {
        MsgBox("Global app variable not found! Cannot verify hotkeys.", "Error", "Icon!")
        return
    }

    if !app.hotkeyManager {
        MsgBox("HotkeyManager not found! Cannot verify hotkeys.", "Error", "Icon!")
        return
    }

    ; Log current hotkey configuration
    app.logger.Log("=== HOTKEY VERIFICATION ===")
    app.logger.Log("Config hotkeys:")
    app.logger.Log("  - changeHotkey: " (app.config.changeHotkey ? app.config.changeHotkey : "none"))
    app.logger.Log("  - pauseHotkey: " (app.config.pauseHotkey ? app.config.pauseHotkey : "none"))
    app.logger.Log("  - settingsHotkey: " (app.config.settingsHotkey ? app.config.settingsHotkey : "none"))

    app.logger.Log("Registered hotkeys: " app.hotkeyManager.registeredHotkeys.Count)
    for label, info in app.hotkeyManager.registeredHotkeys {
        app.logger.Log("  - " label ": " info.hotkey)
    }

    ; Check if config hotkeys match registered hotkeys
    mismatches := []

    ; Check change hotkey
    if app.config.changeHotkey && app.config.changeHotkey != "" {
        if !app.hotkeyManager.registeredHotkeys.Has("ChangeCursor") ||
        app.hotkeyManager.registeredHotkeys["ChangeCursor"].hotkey != app.config.changeHotkey {
            mismatches.Push("Change cursor hotkey mismatch")
        }
    }

    ; Check pause hotkey
    if app.config.pauseHotkey && app.config.pauseHotkey != "" {
        if !app.hotkeyManager.registeredHotkeys.Has("PauseResume") ||
        app.hotkeyManager.registeredHotkeys["PauseResume"].hotkey != app.config.pauseHotkey {
            mismatches.Push("Pause/resume hotkey mismatch")
        }
    }

    ; Check settings hotkey
    if app.config.settingsHotkey && app.config.settingsHotkey != "" {
        if !app.hotkeyManager.registeredHotkeys.Has("ShowSettings") ||
        app.hotkeyManager.registeredHotkeys["ShowSettings"].hotkey != app.config.settingsHotkey {
            mismatches.Push("Settings hotkey mismatch")
        }
    }

    ; Report results
    if mismatches.Length > 0 {
        app.logger.Log("VERIFICATION FAILED: " mismatches.Length " mismatches found")
        for i, mismatch in mismatches {
            app.logger.Log("  - " mismatch)
        }

        ; Try to fix by re-registering
        app.logger.Log("Attempting to fix by re-registering hotkeys...")
        app.hotkeyManager.RegisterHotkeys()

        MsgBox("Hotkey verification failed. " mismatches.Length " mismatches found.`n`n"
            "The system has attempted to fix this by re-registering all hotkeys.`n`n"
            "Check the log file for details.", "Hotkey Verification", "Icon!")
    } else {
        app.logger.Log("VERIFICATION PASSED: All hotkeys properly registered")
        MsgBox("All hotkeys are properly registered and should be working.", "Hotkey Verification", "Icon!")
    }
}

/**
 * A function to force re-register all hotkeys
 * Call this if hotkeys stop working
 */
ForceRegisterHotkeys() {
    global app

    if !IsSet(app) || !app {
        MsgBox("Global app variable not found! Cannot register hotkeys.", "Error", "Icon!")
        return
    }

    if !app.hotkeyManager {
        MsgBox("HotkeyManager not found! Cannot register hotkeys.", "Error", "Icon!")
        return
    }

    app.logger.Log("Force re-registering all hotkeys")
    app.hotkeyManager.UnregisterAllHotkeys()
    app.hotkeyManager.RegisterHotkeys()

    MsgBox("Hotkeys have been force re-registered.", "Hotkeys", "Info")
}
