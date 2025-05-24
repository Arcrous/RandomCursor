#Requires AutoHotkey v2.0
/**
 * Config.ahk - Configuration management for RandomCursor++
 * Handles loading, saving, and accessing application settings
 */
class Config {
    ; Default configuration values
    changeInterval := 300      ; in seconds (default: 5 minutes)
    enableNotifications := true
    logChanges := true
    excludeSchemes := []       ; Scheme names to exclude

    ; Hotkey configuration values
    changeHotkey := "^+c"         ; Hotkey to change cursor scheme
    pauseHotkey := "^+p"          ; Hotkey to pause/resume timer
    settingsHotkey := "^+s"       ; Hotkey to open settings

    ; Reference to logger
    logger := ""

    __New(logger) {
        this.logger := logger
        this.logger.Log("Config: Initializing configuration")

        ; TODO: In the future, we could add loading from an INI file here
        this.LoadFromFile()
    }

    /**
     * Updates configuration values
     * @param newInterval - New interval in seconds
     * @param enableNotifications - Whether to show notifications
     * @param logChanges - Whether to log changes
     * @param excludeSchemes - Array of scheme names to exclude
     * @param changeHotkey - Hotkey to change cursor scheme
     * @param pauseHotkey - Hotkey to pause/resume timer
     * @param settingsHotkey - Hotkey to open settings
     */
    UpdateSettings(newInterval, enableNotifications, logChanges, excludeSchemes, changeHotkey := "", pauseHotkey := "",
        settingsHotkey := "") {
        ; Validate interval
        if (newInterval < 10) {
            MsgBox("Interval must be at least 10 seconds.", "Invalid Setting", "Icon!")
            return false
        }

        ; Update config values
        this.changeInterval := newInterval
        this.enableNotifications := enableNotifications
        this.logChanges := logChanges
        this.excludeSchemes := excludeSchemes

        ; Update hotkeys if provided
        if (changeHotkey != "")
            this.changeHotkey := changeHotkey
        if (pauseHotkey != "")
            this.pauseHotkey := pauseHotkey
        if (settingsHotkey != "")
            this.settingsHotkey := settingsHotkey

        this.logger.Log("Config: Settings updated: Interval=" this.changeInterval
            ", Notifications=" this.enableNotifications
            ", Change Hotkey=" this.changeHotkey
            ", Pause Hotkey=" this.pauseHotkey
            ", Settings Hotkey=" this.settingsHotkey)

        ; Save settings to INI file
        this.SaveToFile()

        return true
    }

    /**
     * Validates if a scheme should be excluded
     * @param schemeName - Name of the scheme to check
     * @return true if scheme should be excluded, false otherwise
     */
    IsSchemeExcluded(schemeName) {
        return this.HasValue(this.excludeSchemes, schemeName)
    }

    /**
     * Checks if an array contains a value
     * @param arr - Array to check
     * @param value - Value to look for
     * @return true if value is found, false otherwise
     */
    HasValue(arr, value) {
        if (!IsObject(arr))
            return false

        for item in arr {
            if (item = value)
                return true
        }
        return false
    }

    /**
     * Load settings from INI file
     */
    LoadFromFile() {
        iniPath := A_ScriptDir "\RandomCursor.ini"

        if (!FileExist(iniPath)) {
            this.logger.Log("Config: No INI file found, using defaults")
            return
        }

        try {
            ; Load general settings
            this.changeInterval := IniRead(iniPath, "General", "ChangeInterval", this.changeInterval)
            this.enableNotifications := IniRead(iniPath, "General", "EnableNotifications", this.enableNotifications)
            this.logChanges := IniRead(iniPath, "General", "LogChanges", this.logChanges)

            ; Load hotkeys
            this.changeHotkey := IniRead(iniPath, "Hotkeys", "ChangeHotkey", this.changeHotkey)
            this.pauseHotkey := IniRead(iniPath, "Hotkeys", "PauseHotkey", this.pauseHotkey)
            this.settingsHotkey := IniRead(iniPath, "Hotkeys", "SettingsHotkey", this.settingsHotkey)

            ; Load excluded schemes
            excludedList := IniRead(iniPath, "General", "ExcludedSchemes", "")
            if (excludedList != "") {
                this.excludeSchemes := StrSplit(excludedList, "|")
            }

            this.logger.Log("Config: Settings loaded from INI file")
            this.logger.Log("Config: Interval=" this.changeInterval ", Notifications=" this.enableNotifications)

        } catch as e {
            this.logger.Log("Config: Error loading INI file: " e.Message)
        }
    }

    /**
     * Save settings to INI file
     */
    SaveToFile() {
        iniPath := A_ScriptDir "\RandomCursor.ini"

        try {
            ; Save general settings
            IniWrite(this.changeInterval, iniPath, "General", "ChangeInterval")
            IniWrite(this.enableNotifications, iniPath, "General", "EnableNotifications")
            IniWrite(this.logChanges, iniPath, "General", "LogChanges")

            ; Save excluded schemes as pipe-separated string
            excludedStr := ""
            for index, scheme in this.excludeSchemes {
                if (index > 1)
                    excludedStr .= "|"
                excludedStr .= scheme
            }
            IniWrite(excludedStr, iniPath, "General", "ExcludedSchemes")

            ; Save hotkeys
            IniWrite(this.changeHotkey, iniPath, "Hotkeys", "ChangeHotkey")
            IniWrite(this.pauseHotkey, iniPath, "Hotkeys", "PauseHotkey")
            IniWrite(this.settingsHotkey, iniPath, "Hotkeys", "SettingsHotkey")

            this.logger.Log("Config: Settings saved to INI file")

        } catch as e {
            this.logger.Log("Config: Error saving INI file: " e.Message)
        }
    }
}
