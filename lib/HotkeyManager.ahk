#Requires AutoHotkey v2.0
/**
 * HotkeyManager.ahk - Handles hotkey registration and management
 * Provides functionality to register, unregister, and manage hotkeys
 */
class HotkeyManager {
    ; Reference to other components
    config := ""
    cursorManager := ""
    ui := ""
    logger := ""

    ; Store registered hotkeys
    registeredHotkeys := Map()

    __New(config, cursorManager, ui, logger) {
        this.config := config
        this.cursorManager := cursorManager
        this.ui := ui
        this.logger := logger

        this.logger.Log("HotkeyManager: Initializing")
    }

    /**
     * Registers all configured hotkeys
     */
    RegisterHotkeys() {
        ; First, make sure all existing hotkeys are unregistered
        this.UnregisterAllHotkeys()

        ; Register change cursor hotkey
        if (this.config.changeHotkey && this.config.changeHotkey != "") {
            this.RegisterHotkey(this.config.changeHotkey, ObjBindMethod(this.cursorManager, "ChangeCursorScheme"),
            "ChangeCursor")
        }

        ; Register pause/resume hotkey
        if (this.config.pauseHotkey && this.config.pauseHotkey != "") {
            this.RegisterHotkey(this.config.pauseHotkey, ObjBindMethod(this.ui, "ToggleTimerTray"),
            "PauseResume")
        }

        ; Register settings hotkey
        if (this.config.settingsHotkey && this.config.settingsHotkey != "") {
            this.RegisterHotkey(this.config.settingsHotkey, ObjBindMethod(this.ui, "ShowSettingsGUI"),
            "ShowSettings")
        }

        this.logger.Log("HotkeyManager: Registered " this.registeredHotkeys.Count " hotkeys")
    }

    /**
     * Registers a single hotkey
     * @param hotkeyString - Hotkey string (e.g., "^!c")
     * @param callback - Function to call when hotkey is pressed
     * @param label - Identifier for the hotkey
     * @return True if registration succeeded, false otherwise
     */
    RegisterHotkey(hotkeyString, callback, label) {
        try {
            ; Make sure to unregister any existing hotkey with this label
            this.UnregisterHotkey(label)

            ; Register the new hotkey with error handling
            try {
                Hotkey(hotkeyString, callback)

                ; Store the registration
                this.registeredHotkeys[label] := {
                    hotkey: hotkeyString,
                    callback: callback
                }

                this.logger.Log("HotkeyManager: Registered hotkey " hotkeyString " as " label)
                return true
            } catch as err {
                this.logger.Log("HotkeyManager: Failed to register hotkey " hotkeyString ": " err.Message)
                return false
            }
        }
        catch as e {
            this.logger.Log("HotkeyManager: Failed to register hotkey " hotkeyString ": " e.Message)
            return false
        }
    }

    /**
     * Unregisters a hotkey by label
     * @param label - Identifier for the hotkey to unregister
     */
    UnregisterHotkey(label) {
        if (this.registeredHotkeys.Has(label)) {
            try {
                hotkeyInfo := this.registeredHotkeys[label]
                Hotkey(hotkeyInfo.hotkey, "Off")
                this.logger.Log("HotkeyManager: Unregistered hotkey " hotkeyInfo.hotkey)
                this.registeredHotkeys.Delete(label)
            }
            catch as e {
                this.logger.Log("HotkeyManager: Error unregistering hotkey: " e.Message)
            }
        }
    }

    /**
     * Unregisters all hotkeys
     */
    UnregisterAllHotkeys() {
        ; Create a temporary copy of keys to avoid modification during iteration
        keys := []
        for label, _ in this.registeredHotkeys {
            keys.Push(label)
        }

        ; Now unregister each hotkey
        for _, label in keys {
            this.UnregisterHotkey(label)
        }

        ; Make sure the map is empty
        this.registeredHotkeys := Map()
        this.logger.Log("HotkeyManager: Unregistered all hotkeys")
    }

    /**
     * Validates a hotkey string
     * @param hotkeyString - Hotkey string to validate
     * @return True if valid, false otherwise
     */
    IsValidHotkey(hotkeyString) {
        ; Basic validation
        if (!hotkeyString || hotkeyString == "")
            return true  ; Empty is considered valid (no hotkey)

        try {
            ; Try to register to a dummy function temporarily
            dummyCallback := (*) => {}
            Hotkey(hotkeyString, dummyCallback)

            ; If we get here, it's valid, so unregister it
            Hotkey(hotkeyString, "Off")
            return true
        }
        catch {
            return false
        }
    }
}
