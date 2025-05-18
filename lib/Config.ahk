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
        ; this.LoadFromFile()
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

        ; TODO: In the future, we could add saving to an INI file here
        ; this.SaveToFile()

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
     * Future method for loading settings from file
     */
    LoadFromFile() {
        ; TODO: Implement loading from INI file
    }

    /**
     * Future method for saving settings to file
     */
    SaveToFile() {
        ; TODO: Implement saving to INI file
    }
}
